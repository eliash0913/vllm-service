Name:           vllm-service
Version:        0.11.0
Release:        1%{?dist}
Summary:        vLLM service daemon
License:        Apache-2.0
URL:            https://github.com/vllm-project/vllm
Source0:        vllm-service-%{version}.tar.gz
BuildArch:      x86_64
Requires:       python3
Requires(pre):  shadow-utils
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

%description
Packages vLLM with a systemd service wrapper.

%prep
%setup -q -c -T

%build

%install
mkdir -p %{buildroot}
tar -xzf %{SOURCE0} -C %{buildroot}

%pre
getent group vllm >/dev/null || groupadd -r vllm
getent passwd vllm >/dev/null || useradd -r -g vllm -s /sbin/nologin -d /opt/vllm vllm

%post
%systemd_post vllm.service

%preun
%systemd_preun vllm.service

%postun
%systemd_postun_with_restart vllm.service

%files
/opt/vllm
%config(noreplace) /etc/vllm/vllm.env
/usr/lib/systemd/system/vllm.service

%changelog
