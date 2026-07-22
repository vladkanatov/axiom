# axiom

axiom is a small Swift-based virtualization control plane for Apple Silicon.

## Build

```bash
swift build
```

## Run

```bash
swift run axiom
```

The executable starts a local HTTP server with stubbed REST endpoints under `/api/v1`.

## Project Layout

- `Sources/AxiomCore` - VM models, state, and manager actor
- `Sources/AxiomRESTAPI` - HTTP server and REST router
- `Sources/AxiomVirtualization` - native virtualization provider stub
- `Tests` - unit and integration test targets
