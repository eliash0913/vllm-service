Name:           vservice
Version:        0.11.0
Release:        1%{?dist}
Summary:        vservice wrapper daemon for vLLM
License:        Apache-2.0
URL:            https://github.com/vllm-project/vllm
Source0:        vservice-%{version}.tar.gz
BuildArch:      x86_64
Requires:       python3
Requires(pre):  shadow-utils
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

%description
Packages vLLM with the vservice systemd wrapper.

%prep
%setup -q -c -T

%build

%install
mkdir -p %{buildroot}
tar -xzf %{SOURCE0} -C %{buildroot}

%pre
getent group vservice >/dev/null || groupadd -r vservice
getent passwd vservice >/dev/null || useradd -r -g vservice -s /sbin/nologin -d /opt/vllm vservice

%post
%systemd_post vservice.service

%preun
%systemd_preun vservice.service

%postun
%systemd_postun_with_restart vservice.service

%files
/opt/vllm
%config(noreplace) /etc/vllm/vllm.env
/usr/lib/systemd/system/vservice.service

%changelog
