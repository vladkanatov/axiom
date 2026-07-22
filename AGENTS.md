# Axiom@ – Native Virtualization Manager for Apple Silicon

## Project Overview

**Axiom** is a Swift‑based daemon and REST API server that provides a **libvirt‑like** interface for managing virtual machines on Apple Silicon (ARM) Macs. It leverages Apple’s native `Virtualization.Framework` to create, run, and control lightweight VMs, exposing a clean, language‑agnostic HTTP API (and optional Unix socket) for external clients.

The goal is to offer a robust, production‑ready virtualization control plane for macOS, suitable for CI/CD, development environments, and edge deployments.

---

## Coding Conventions

- **Language**: Swift
- **Style**: Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and the [SwiftLint](https://github.com/realm/SwiftLint) default configuration.
- **Naming**:
  - Types: `UpperCamelCase`
  - Variables/functions: `lowerCamelCase`
  - Constants: `lowerCamelCase` (not `SCREAMING_SNAKE_CASE`)
  - Avoid abbreviations except for well‑known acronyms (e.g., `VM`, `API`).
- **Concurrency**: Use Swift’s structured concurrency (`async`/`await`, `Task`, `Actor`) for all asynchronous operations. The `VMManager` must be an `Actor` to protect shared state.
- **Error Handling**: Define a hierarchy of `AxiomError` (enum with associated values) that conforms to `LocalizedError`. Never force‑unwrap optionals; prefer `guard` or `try?` with explicit handling.
- **Logging**: Use `os.log` with appropriate subsystems and categories. Log at `.debug` for development, `.info` for significant events, `.error` for failures.
- **Documentation**: Add `///` comments for all public interfaces, including parameters and return values.

---

## Architecture Principles

- **Separation of Concerns**: The `Virtualization` layer knows only about the Framework and translates raw `VZVirtualMachine` events. The `VMManager` owns VM lifecycles and state machines. The `RESTAPI`/`SocketAPI` layers handle external requests and translate them to manager calls.
- **Event‑Driven**: Use `AsyncStream` or `NotificationCenter` to broadcast VM state changes (running, paused, stopped, error) to all active API connections.
- **State Persistence**: VM configurations (CPU, memory, disks, network) are stored as JSON files in `~/.axiom/vms/`. Images reside in `~/.axiom/images/`. Use `Codable` for serialization.
- **Security**: The REST API listens on `127.0.0.1` by default with an optional API key (set via environment variable). Unix socket permissions restrict access to the current user.
- **Extensibility**: Design protocols (`VirtualizationProvider`, `NetworkProvider`) to allow alternative backends in the future (e.g., QEMU, Rosetta).

---

## Virtualization.Framework Specifics

- **Minimum OS**: macOS 13.0 (Ventura) for `VZVirtualMachine` support on Apple Silicon.
- **Key Classes**:
  - `VZVirtualMachineConfiguration` – define CPU count, memory, boot loader, network, storage, etc.
  - `VZMacOSRestoreImage` – for macOS guests; for Linux use `VZLinuxBootLoader` with a kernel/initrd.
  - `VZDirectorySharingDevice` – for host‑guest file sharing (optional).
  - `VZNetworkDevice` – configure NAT or bridged networking using `VZBridgedNetworkInterface`.
- **Concurrency**: Framework callbacks run on arbitrary queues; always dispatch to the main `VMManager` actor for state mutations.
- **Error Recovery**: Gracefully handle `VZError` and translate to `AxiomError`. If a VM crashes, log the reason and attempt to restart with a backoff policy if configured.

---

## REST API Design

- **Base URL**: `http://127.0.0.1:8080/api/v1` (configurable via environment variable `AXIOM_PORT`).
- **Content‑Type**: `application/json` for all requests/responses.
- **Endpoints**:

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/vms` | List all VMs (name, state, UUID) |
| `POST` | `/vms` | Create a new VM from a JSON configuration |
| `GET`  | `/vms/{uuid}` | Get VM details (full configuration + status) |
| `PUT`  | `/vms/{uuid}` | Update VM configuration (only if stopped) |
| `POST` | `/vms/{uuid}/start` | Start the VM |
| `POST` | `/vms/{uuid}/stop` | Stop (shut down) the VM gracefully |
| `POST` | `/vms/{uuid}/force-stop` | Force‑stop the VM (kill) |
| `POST` | `/vms/{uuid}/pause` | Pause execution |
| `POST` | `/vms/{uuid}/resume` | Resume from pause |
| `DELETE` | `/vms/{uuid}` | Delete the VM (remove config and disk files) |
| `GET`  | `/images` | List available disk images (`.img`, `.dmg`) |
| `POST` | `/images` | Import a new disk image from a URL or local path |

- **Response format**:
  ```json
  {
    "success": true,
    "data": { ... },
    "error": null
  }