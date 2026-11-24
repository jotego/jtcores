# Native capture controller test

Verifies the deterministic row counter, two-slot publication and consumption,
exact row budget, boundary pause release, and liveness when the next BEGIN
arrives during drain. The final case sends BEGIN on the same edge as the drain
release boundary.
