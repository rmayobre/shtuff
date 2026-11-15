# GPU

Linux only. Detect GPUs, pick one for a container and install drivers.

> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.

## `gpu_list`

_Source: `src/linux/gpu/gpu_list.sh`_

```text
Function: gpu_list
Description: Lists all GPU devices detected on the host system. Uses lspci to
             enumerate PCI-attached GPUs (VGA, 3D, and Display controllers) and
             prints each with its PCI address, detected vendor, and description.

Arguments:
  None

Globals:
  None

Returns:
  0 - One or more GPUs detected and listed.
  1 - lspci (pciutils) is not available on this system.
  2 - No GPU devices detected.

Examples:
  gpu_list
```

## `gpu_select`

_Source: `src/linux/gpu/gpu_select.sh`_

```text
Function: gpu_select
Description: Interactively prompts the user to choose a GPU from the host's
             detected PCI GPU devices. When --container is provided the selected
             GPU is automatically configured for passthrough into that container
             using the appropriate backend (PCT hostpci or LXC cgroup/mount).
             The selected GPU descriptor is always stored in the global variable
             'answer' regardless of whether --container is given.

Arguments:
  --container NAME (string, optional): Container name or VMID to configure GPU
      passthrough for after the user makes a selection.
  --index N (integer, optional, default: 0): hostpci slot index to use when
      configuring PCT passthrough. Ignored for LXC backends.
  --pcie (flag, optional): Enable PCIe passthrough mode (pcie=1) for PCT. Has
      no effect on LXC backends.
  --dry-run (flag, optional): Print the passthrough commands that would be
      executed without applying them. Defaults to IS_DRY_RUN if not specified.

Globals:
  answer (write): Set to the full GPU descriptor string of the selected GPU,
      e.g. "01:00.0 NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)".
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.

Returns:
  0 - Selection made (and passthrough configured if --container was provided).
  1 - lspci not available, no GPUs found, or invalid arguments.
  2 - Container not found or passthrough configuration failed.

Examples:
  gpu_select
  echo "You selected: $answer"

  gpu_select --container mycontainer
  gpu_select --container 100 --pcie
  gpu_select --container 101 --index 1 --pcie --dry-run
```

## `gpu_install`

_Source: `src/linux/gpu/gpu_install.sh`_

```text
Function: gpu_install
Description: Installs hardware acceleration libraries on the host or inside a
             container. Auto-detects the GPU vendor via lspci when --vendor is
             omitted. Supports NVIDIA (CUDA toolkit + container toolkit), AMD
             (ROCm + OpenCL), Intel (VA-API + OpenCL), and a generic OpenCL
             fallback. When --container is provided the packages are installed
             inside the named container via its exec backend. Package manager
             detection is performed inside the container, not on the host.

Arguments:
  --vendor VENDOR (string, optional, default: auto): GPU vendor to target.
      Valid values: nvidia, amd, intel, generic.
      When omitted the vendor is detected via lspci. Falls back to generic
      if detection fails or produces an ambiguous result.
  --container NAME (string, optional): Container name or VMID to install
      libraries inside. When omitted libraries are installed on the host.
  --style STYLE (string, optional, default: spinner): Loading indicator style.
      Valid values: spinner, dots, bars, arrows, clock.
  --dry-run (flag, optional): Print the commands that would be run without
      executing them. Defaults to IS_DRY_RUN if not specified.

Globals:
  IS_DRY_RUN (read): When "true", enables dry-run mode by default.
  SPINNER_LOADING_STYLE (read): Default loading style constant.

Returns:
  0 - Libraries installed successfully.
  1 - Invalid arguments or unsupported vendor specified.
  2 - Package installation failed.
  3 - Container not found or exec into container failed.

Examples:
  gpu_install
  gpu_install --vendor nvidia
  gpu_install --vendor amd --style dots
  gpu_install --vendor intel --container mycontainer
  gpu_install --container 100 --dry-run
```
