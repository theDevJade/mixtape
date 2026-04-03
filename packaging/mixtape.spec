Name:           mixtape
Version:        0.2.0
Release:        1%{?dist}
Summary:        Open-source, customizable music player with SteamVR overlay support

License:        MIT
URL:            https://github.com/theDevJade/mixtape
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  flutter
BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  clang
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  pkg-config
BuildRequires:  gtk3-devel
BuildRequires:  webkit2gtk4.1-devel
BuildRequires:  mpv-libs-devel
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib

Requires:       mpv-libs
Requires:       gtk3

%description
Mixtape is an open-source, highly customizable music player built with Flutter.
It includes an optional SteamVR dashboard overlay that lets you control playback
from within any VR environment.

%prep
%autosetup

%build
# Build the SteamVR Rust bridge
pushd mixtape_vr
cargo build --release --features steamvr
popd

# Build the Flutter Linux release bundle
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release

%install
# Install the Flutter bundle
install -d %{buildroot}%{_libdir}/%{name}
cp -r build/linux/x64/release/bundle/. %{buildroot}%{_libdir}/%{name}/

# Bundle the VR shared library alongside the app
install -m 755 mixtape_vr/target/release/libmixtape_vr.so \
    %{buildroot}%{_libdir}/%{name}/lib/libmixtape_vr.so

# Launcher wrapper (sets locale for number parsing compatibility)
install -d %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/%{name} << 'EOF'
#!/bin/bash
export LC_NUMERIC=C
exec %{_libdir}/%{name}/%{name} "$@"
EOF
chmod 755 %{buildroot}%{_bindir}/%{name}

# Desktop entry
install -d %{buildroot}%{_datadir}/applications
cat > %{buildroot}%{_datadir}/applications/%{name}.desktop << 'EOF'
[Desktop Entry]
Name=Mixtape
Comment=Open-source music player with SteamVR overlay
Exec=mixtape
Icon=mixtape
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Player;
EOF
desktop-file-validate %{buildroot}%{_datadir}/applications/%{name}.desktop

%files
%license LICENSE
%{_bindir}/%{name}
%{_libdir}/%{name}/
%{_datadir}/applications/%{name}.desktop

%changelog
* Mon Jan 01 2024 Maintainer <maintainer@example.com> - 0.1.0-1
- Initial package
