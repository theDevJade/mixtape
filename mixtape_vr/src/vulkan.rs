//! Vulkan texture-upload backend for mixtape_vr.
//!
//! Initialised via `init()` after OpenVR is up.  Uploads RGBA frames via a
//! staging-buffer → device-image path and submits them to SteamVR with
//! `SetOverlayTexture`.  Falls back gracefully (`is_available()` returns false)
//! if the Vulkan loader is absent or device creation fails.

use std::ffi::CString;
use std::sync::Mutex;

use ash::vk;
use ash::vk::Handle;
use openvr_sys as sys;

// ─── Global state ────────────────────────────────────────────────────────────

struct VulkanState {
    /// Kept alive so the function-pointer table lives as long as the instance.
    _entry:           ash::Entry,
    instance:         ash::Instance,
    physical_device:  vk::PhysicalDevice,
    mem_props:        vk::PhysicalDeviceMemoryProperties,
    device:           ash::Device,
    queue:            vk::Queue,
    queue_family_idx: u32,
    cmd_pool:         vk::CommandPool,
    cmd_buf:          vk::CommandBuffer,
    fence:            vk::Fence,
    // Cached GPU image (recreated whenever resolution changes).
    image:            vk::Image,
    image_mem:        vk::DeviceMemory,
    image_width:      u32,
    image_height:     u32,
    // Persistently-mapped staging buffer (recreated when too small).
    staging_buf:      vk::Buffer,
    staging_mem:      vk::DeviceMemory,
    staging_ptr:      *mut u8,
    staging_size:     vk::DeviceSize,
}

// SAFETY: raw pointers are only touched inside the Mutex.
unsafe impl Send for VulkanState {}

static STATE: Mutex<Option<VulkanState>> = Mutex::new(None);

// ─── Handle-to-pointer cast ───────────────────────────────────────────────────
//
// Vulkan dispatchable handles are pointers on the Vulkan API side.
// openvr_sys represents them as `*mut VkXxx_T` (opaque zero-sized structs).
// ash represents them as newtype wrappers over u64; `as_raw()` gives the u64.

macro_rules! as_openvr_ptr {
    ($handle:expr, $T:ty) => {
        $handle.as_raw() as usize as *mut $T
    };
}

// ─── Public surface ───────────────────────────────────────────────────────────

/// Initialise Vulkan.  Never panics; failures are logged and `is_available`
/// returns false so the CPU overlay path is used instead.
pub unsafe fn init() {
    let mut guard = STATE.lock().unwrap();
    if guard.is_some() {
        return;
    }
    match create_state() {
        Ok(s)  => { eprintln!("[mvr/vulkan] initialised OK"); *guard = Some(s); }
        Err(e) => { eprintln!("[mvr/vulkan] init failed (will use CPU fallback): {}", e); }
    }
}

pub fn is_available() -> bool {
    STATE.lock().unwrap().is_some()
}

pub fn shutdown() {
    if let Some(s) = STATE.lock().unwrap().take() {
        unsafe { destroy_state(s); }
        eprintln!("[mvr/vulkan] shut down");
    }
}

/// Upload `rgba` bytes (width × height × 4) to a Vulkan image and submit it
/// to SteamVR overlay `handle` via `SetOverlayTexture`.
/// Returns 0 on success, -1 on any error.
pub unsafe fn submit_texture(
    handle: u64,
    rgba:   *const u8,
    width:  u32,
    height: u32,
    ot:     *mut sys::VR_IVROverlay_FnTable,
) -> i32 {
    let mut guard = STATE.lock().unwrap();
    let s = match guard.as_mut() { Some(s) => s, None => return -1 };
    match do_submit(s, handle, rgba, width, height, ot) {
        Ok(())  => 0,
        Err(e) => { eprintln!("[mvr/vulkan] submit_texture: {}", e); -1 }
    }
}

// ─── IVRCompositor helper ─────────────────────────────────────────────────────

unsafe fn compositor_table() -> *mut sys::VR_IVRCompositor_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        b"FnTable:IVRCompositor_029\0".as_ptr() as *const std::os::raw::c_char,
        &mut err,
    );
    iface as *mut sys::VR_IVRCompositor_FnTable
}

/// Space-separated extension string → Vec<CString>.
fn parse_ext_string(buf: &[u8]) -> Vec<CString> {
    let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
    std::str::from_utf8(&buf[..end]).unwrap_or("").split_whitespace()
        .filter_map(|s| CString::new(s).ok())
        .collect()
}

unsafe fn required_instance_extensions() -> Vec<CString> {
    let ct = compositor_table();
    if ct.is_null() { return vec![]; }
    let f = match (*ct).GetVulkanInstanceExtensionsRequired { Some(f) => f, None => return vec![] };

    let n = f(std::ptr::null_mut(), 0);
    if n == 0 { return vec![]; }
    let mut buf = vec![0u8; n as usize];
    f(buf.as_mut_ptr() as *mut _, n);
    parse_ext_string(&buf)
}

unsafe fn required_device_extensions(
    ct: *mut sys::VR_IVRCompositor_FnTable,
    pd: vk::PhysicalDevice,
) -> Vec<CString> {
    if ct.is_null() { return vec![]; }
    let f = match (*ct).GetVulkanDeviceExtensionsRequired { Some(f) => f, None => return vec![] };

    let raw_pd = as_openvr_ptr!(pd, sys::VkPhysicalDevice_T);
    let n = f(raw_pd, std::ptr::null_mut(), 0);
    if n == 0 { return vec![]; }
    let mut buf = vec![0u8; n as usize];
    f(raw_pd, buf.as_mut_ptr() as *mut _, n);
    parse_ext_string(&buf)
}

// ─── Memory helpers ───────────────────────────────────────────────────────────

fn find_memory_type(
    props:     &vk::PhysicalDeviceMemoryProperties,
    type_bits: u32,
    required:  vk::MemoryPropertyFlags,
) -> Option<u32> {
    (0..props.memory_type_count).find(|&i| {
        type_bits & (1 << i) != 0
            && props.memory_types[i as usize].property_flags.contains(required)
    })
}

// ─── Initialisation ───────────────────────────────────────────────────────────

unsafe fn create_state() -> Result<VulkanState, String> {
    // ── Vulkan entry (load the loader) ────────────────────────────────────────
    let entry = ash::Entry::load()
        .map_err(|e| format!("load Vulkan: {e}"))?;

    // ── Instance extensions ───────────────────────────────────────────────────
    let inst_exts    = required_instance_extensions();
    let inst_ext_ptrs: Vec<*const i8> = inst_exts.iter().map(|s| s.as_ptr()).collect();

    let app_name = CString::new("mixtape_vr").unwrap();
    let app_info = vk::ApplicationInfo::default()
        .application_name(&app_name)
        .application_version(vk::make_api_version(0, 0, 1, 0))
        .api_version(vk::API_VERSION_1_0);

    let inst_ci = vk::InstanceCreateInfo::default()
        .application_info(&app_info)
        .enabled_extension_names(&inst_ext_ptrs);

    let instance = entry.create_instance(&inst_ci, None)
        .map_err(|e| format!("create_instance: {e}"))?;

    // ── Physical device ───────────────────────────────────────────────────────
    let phys_devices = instance.enumerate_physical_devices()
        .map_err(|e| { unsafe { instance.destroy_instance(None) }; format!("enumerate: {e}") })?;

    if phys_devices.is_empty() {
        instance.destroy_instance(None);
        return Err("no Vulkan physical devices".into());
    }
    let physical_device = phys_devices[0];
    let mem_props = instance.get_physical_device_memory_properties(physical_device);

    // ── Queue family (prefer TRANSFER, accept GRAPHICS) ───────────────────────
    let qfps = instance.get_physical_device_queue_family_properties(physical_device);
    let queue_family_idx = qfps.iter().enumerate()
        .find(|(_, p)| p.queue_flags.contains(vk::QueueFlags::TRANSFER)
                        && !p.queue_flags.contains(vk::QueueFlags::GRAPHICS))
        .or_else(|| qfps.iter().enumerate()
            .find(|(_, p)| p.queue_flags.contains(vk::QueueFlags::GRAPHICS)))
        .map(|(i, _)| i as u32)
        .ok_or_else(|| { unsafe { instance.destroy_instance(None) }; "no suitable queue".to_string() })?;

    // ── Device extensions ─────────────────────────────────────────────────────
    let ct = compositor_table();
    let dev_exts     = required_device_extensions(ct, physical_device);
    let dev_ext_ptrs: Vec<*const i8> = dev_exts.iter().map(|s| s.as_ptr()).collect();

    let prios  = [1.0f32];
    let qci    = vk::DeviceQueueCreateInfo::default()
        .queue_family_index(queue_family_idx)
        .queue_priorities(&prios);
    let qcis   = [qci];

    let dev_ci = vk::DeviceCreateInfo::default()
        .queue_create_infos(&qcis)
        .enabled_extension_names(&dev_ext_ptrs);

    let device = instance.create_device(physical_device, &dev_ci, None)
        .map_err(|e| { unsafe { instance.destroy_instance(None) }; format!("create_device: {e}") })?;

    let queue = device.get_device_queue(queue_family_idx, 0);

    // ── Command pool + buffer ─────────────────────────────────────────────────
    let pool_ci = vk::CommandPoolCreateInfo::default()
        .queue_family_index(queue_family_idx)
        .flags(vk::CommandPoolCreateFlags::RESET_COMMAND_BUFFER);
    let cmd_pool = device.create_command_pool(&pool_ci, None)
        .map_err(|e| format!("create_command_pool: {e}"))?;

    let alloc_info = vk::CommandBufferAllocateInfo::default()
        .command_pool(cmd_pool)
        .level(vk::CommandBufferLevel::PRIMARY)
        .command_buffer_count(1);
    let cmd_bufs = device.allocate_command_buffers(&alloc_info)
        .map_err(|e| format!("allocate_command_buffers: {e}"))?;
    let cmd_buf  = cmd_bufs[0];

    let fence = device.create_fence(&vk::FenceCreateInfo::default(), None)
        .map_err(|e| format!("create_fence: {e}"))?;

    Ok(VulkanState {
        _entry: entry,
        instance,
        physical_device,
        mem_props,
        device,
        queue,
        queue_family_idx,
        cmd_pool,
        cmd_buf,
        fence,
        image:        vk::Image::null(),
        image_mem:    vk::DeviceMemory::null(),
        image_width:  0,
        image_height: 0,
        staging_buf:  vk::Buffer::null(),
        staging_mem:  vk::DeviceMemory::null(),
        staging_ptr:  std::ptr::null_mut(),
        staging_size: 0,
    })
}

unsafe fn destroy_state(s: VulkanState) {
    let _ = s.device.device_wait_idle();

    if s.image != vk::Image::null() {
        s.device.destroy_image(s.image, None);
        s.device.free_memory(s.image_mem, None);
    }
    if s.staging_buf != vk::Buffer::null() {
        s.device.unmap_memory(s.staging_mem);
        s.device.destroy_buffer(s.staging_buf, None);
        s.device.free_memory(s.staging_mem, None);
    }
    s.device.destroy_fence(s.fence, None);
    s.device.destroy_command_pool(s.cmd_pool, None);
    s.device.destroy_device(None);
    s.instance.destroy_instance(None);
    // s._entry dropped here
}

// ─── Per-frame resource management ───────────────────────────────────────────

const IMAGE_FORMAT: vk::Format = vk::Format::R8G8B8A8_UNORM;

unsafe fn ensure_staging(s: &mut VulkanState, need: vk::DeviceSize) -> Result<(), String> {
    if need <= s.staging_size {
        return Ok(());
    }
    // Destroy old staging buffer.
    if s.staging_buf != vk::Buffer::null() {
        s.device.unmap_memory(s.staging_mem);
        s.device.destroy_buffer(s.staging_buf, None);
        s.device.free_memory(s.staging_mem, None);
        s.staging_buf  = vk::Buffer::null();
        s.staging_mem  = vk::DeviceMemory::null();
        s.staging_ptr  = std::ptr::null_mut();
        s.staging_size = 0;
    }

    let buf_ci = vk::BufferCreateInfo::default()
        .size(need)
        .usage(vk::BufferUsageFlags::TRANSFER_SRC)
        .sharing_mode(vk::SharingMode::EXCLUSIVE);
    let buf = s.device.create_buffer(&buf_ci, None)
        .map_err(|e| format!("create staging buffer: {e}"))?;

    let req = s.device.get_buffer_memory_requirements(buf);
    let mi  = match find_memory_type(
        &s.mem_props, req.memory_type_bits,
        vk::MemoryPropertyFlags::HOST_VISIBLE | vk::MemoryPropertyFlags::HOST_COHERENT,
    ) {
        Some(i) => i,
        None    => { s.device.destroy_buffer(buf, None); return Err("no host-visible memory".into()); }
    };

    let alloc = vk::MemoryAllocateInfo::default()
        .allocation_size(req.size)
        .memory_type_index(mi);
    let mem = match s.device.allocate_memory(&alloc, None) {
        Ok(m)  => m,
        Err(e) => { s.device.destroy_buffer(buf, None); return Err(format!("alloc staging: {e}")); }
    };

    if let Err(e) = s.device.bind_buffer_memory(buf, mem, 0) {
        s.device.destroy_buffer(buf, None);
        s.device.free_memory(mem, None);
        return Err(format!("bind staging: {e}"));
    }

    let ptr = match s.device.map_memory(mem, 0, vk::WHOLE_SIZE, vk::MemoryMapFlags::empty()) {
        Ok(p)  => p as *mut u8,
        Err(e) => {
            s.device.destroy_buffer(buf, None);
            s.device.free_memory(mem, None);
            return Err(format!("map staging: {e}"));
        }
    };

    s.staging_buf  = buf;
    s.staging_mem  = mem;
    s.staging_ptr  = ptr;
    s.staging_size = need;
    Ok(())
}

unsafe fn ensure_image(s: &mut VulkanState, w: u32, h: u32) -> Result<(), String> {
    if s.image_width == w && s.image_height == h {
        return Ok(());
    }
    // Destroy old image.
    if s.image != vk::Image::null() {
        s.device.destroy_image(s.image, None);
        s.device.free_memory(s.image_mem, None);
        s.image       = vk::Image::null();
        s.image_mem   = vk::DeviceMemory::null();
        s.image_width  = 0;
        s.image_height = 0;
    }

    let img_ci = vk::ImageCreateInfo::default()
        .image_type(vk::ImageType::TYPE_2D)
        .format(IMAGE_FORMAT)
        .extent(vk::Extent3D { width: w, height: h, depth: 1 })
        .mip_levels(1)
        .array_layers(1)
        .samples(vk::SampleCountFlags::TYPE_1)
        .tiling(vk::ImageTiling::OPTIMAL)
        .usage(
            vk::ImageUsageFlags::TRANSFER_DST
            | vk::ImageUsageFlags::TRANSFER_SRC
            | vk::ImageUsageFlags::SAMPLED,
        )
        .sharing_mode(vk::SharingMode::EXCLUSIVE)
        .initial_layout(vk::ImageLayout::UNDEFINED);

    let img = s.device.create_image(&img_ci, None)
        .map_err(|e| format!("create_image {w}x{h}: {e}"))?;

    let req = s.device.get_image_memory_requirements(img);
    let mi  = match find_memory_type(&s.mem_props, req.memory_type_bits, vk::MemoryPropertyFlags::DEVICE_LOCAL) {
        Some(i) => i,
        None    => { s.device.destroy_image(img, None); return Err("no device-local memory".into()); }
    };

    let alloc = vk::MemoryAllocateInfo::default()
        .allocation_size(req.size)
        .memory_type_index(mi);
    let mem = match s.device.allocate_memory(&alloc, None) {
        Ok(m)  => m,
        Err(e) => { s.device.destroy_image(img, None); return Err(format!("alloc image: {e}")); }
    };

    if let Err(e) = s.device.bind_image_memory(img, mem, 0) {
        s.device.destroy_image(img, None);
        s.device.free_memory(mem, None);
        return Err(format!("bind image: {e}"));
    }

    s.image        = img;
    s.image_mem    = mem;
    s.image_width  = w;
    s.image_height = h;
    Ok(())
}

// ─── Per-frame upload + submit ────────────────────────────────────────────────

unsafe fn do_submit(
    s:      &mut VulkanState,
    handle: u64,
    rgba:   *const u8,
    width:  u32,
    height: u32,
    ot:     *mut sys::VR_IVROverlay_FnTable,
) -> Result<(), String> {
    let byte_count = (width * height * 4) as vk::DeviceSize;
    ensure_staging(s, byte_count)?;
    ensure_image(s, width, height)?;

    // Copy frame bytes into the persistently-mapped staging buffer.
    std::ptr::copy_nonoverlapping(rgba, s.staging_ptr, byte_count as usize);

    let cmd = s.cmd_buf;
    let d   = &s.device;

    d.reset_command_buffer(cmd, vk::CommandBufferResetFlags::empty())
        .map_err(|e| format!("reset cmd: {e}"))?;

    let begin_info = vk::CommandBufferBeginInfo::default()
        .flags(vk::CommandBufferUsageFlags::ONE_TIME_SUBMIT);
    d.begin_command_buffer(cmd, &begin_info)
        .map_err(|e| format!("begin cmd: {e}"))?;

    let subresource = vk::ImageSubresourceRange {
        aspect_mask:      vk::ImageAspectFlags::COLOR,
        base_mip_level:   0,
        level_count:      1,
        base_array_layer: 0,
        layer_count:      1,
    };

    // Barrier: UNDEFINED → TRANSFER_DST
    let to_dst = vk::ImageMemoryBarrier {
        old_layout:             vk::ImageLayout::UNDEFINED,
        new_layout:             vk::ImageLayout::TRANSFER_DST_OPTIMAL,
        src_queue_family_index: vk::QUEUE_FAMILY_IGNORED,
        dst_queue_family_index: vk::QUEUE_FAMILY_IGNORED,
        image:                  s.image,
        subresource_range:      subresource,
        src_access_mask:        vk::AccessFlags::empty(),
        dst_access_mask:        vk::AccessFlags::TRANSFER_WRITE,
        ..Default::default()
    };
    d.cmd_pipeline_barrier(
        cmd,
        vk::PipelineStageFlags::TOP_OF_PIPE,
        vk::PipelineStageFlags::TRANSFER,
        vk::DependencyFlags::empty(),
        &[], &[], &[to_dst],
    );

    // Copy staging buffer → image.
    let region = vk::BufferImageCopy {
        buffer_offset:       0,
        buffer_row_length:   0,
        buffer_image_height: 0,
        image_subresource: vk::ImageSubresourceLayers {
            aspect_mask:      vk::ImageAspectFlags::COLOR,
            mip_level:        0,
            base_array_layer: 0,
            layer_count:      1,
        },
        image_offset: vk::Offset3D::default(),
        image_extent: vk::Extent3D { width, height, depth: 1 },
    };
    d.cmd_copy_buffer_to_image(
        cmd, s.staging_buf, s.image,
        vk::ImageLayout::TRANSFER_DST_OPTIMAL,
        &[region],
    );

    // Barrier: TRANSFER_DST → TRANSFER_SRC (SteamVR reads the image).
    let to_src = vk::ImageMemoryBarrier {
        old_layout:             vk::ImageLayout::TRANSFER_DST_OPTIMAL,
        new_layout:             vk::ImageLayout::TRANSFER_SRC_OPTIMAL,
        src_queue_family_index: vk::QUEUE_FAMILY_IGNORED,
        dst_queue_family_index: vk::QUEUE_FAMILY_IGNORED,
        image:                  s.image,
        subresource_range:      subresource,
        src_access_mask:        vk::AccessFlags::TRANSFER_WRITE,
        dst_access_mask:        vk::AccessFlags::TRANSFER_READ,
        ..Default::default()
    };
    d.cmd_pipeline_barrier(
        cmd,
        vk::PipelineStageFlags::TRANSFER,
        vk::PipelineStageFlags::TRANSFER,
        vk::DependencyFlags::empty(),
        &[], &[], &[to_src],
    );

    d.end_command_buffer(cmd).map_err(|e| format!("end cmd: {e}"))?;

    // Submit and wait synchronously (we're on a Flutter timer, not a render thread).
    let cmds   = [cmd];
    let submit = vk::SubmitInfo::default().command_buffers(&cmds);
    d.reset_fences(&[s.fence]).map_err(|e| format!("reset fence: {e}"))?;
    d.queue_submit(s.queue, &[submit], s.fence)
        .map_err(|e| format!("queue_submit: {e}"))?;
    d.wait_for_fences(&[s.fence], true, u64::MAX)
        .map_err(|e| format!("wait fence: {e}"))?;

    // ── SetOverlayTexture ─────────────────────────────────────────────────────
    if ot.is_null() { return Err("overlay fn-table is null".into()); }
    let set_tex = match (*ot).SetOverlayTexture {
        Some(f) => f,
        None    => return Err("SetOverlayTexture fn-ptr is null".into()),
    };

    let raw_inst = s.instance.handle();
    let raw_pd   = s.physical_device;
    let raw_dev  = s.device.handle();
    let raw_q    = s.queue;

    let mut vk_tex = sys::VRVulkanTextureData_t {
        m_nImage:            s.image.as_raw(),
        m_pDevice:           as_openvr_ptr!(raw_dev,  sys::VkDevice_T),
        m_pPhysicalDevice:   as_openvr_ptr!(raw_pd,   sys::VkPhysicalDevice_T),
        m_pInstance:         as_openvr_ptr!(raw_inst, sys::VkInstance_T),
        m_pQueue:            as_openvr_ptr!(raw_q,    sys::VkQueue_T),
        m_nQueueFamilyIndex: s.queue_family_idx,
        m_nWidth:            width,
        m_nHeight:           height,
        m_nFormat:           IMAGE_FORMAT.as_raw() as u32,
        m_nSampleCount:      1,
    };

    let mut texture = sys::Texture_t {
        handle:      &mut vk_tex as *mut _ as *mut std::os::raw::c_void,
        eType:       sys::ETextureType_TextureType_Vulkan,
        eColorSpace: sys::EColorSpace_ColorSpace_Auto,
    };

    let err = set_tex(handle, &mut texture);
    if err != 0 {
        return Err(format!("SetOverlayTexture returned EVROverlayError={err}"));
    }
    Ok(())
}
