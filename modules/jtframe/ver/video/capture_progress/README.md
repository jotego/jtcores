# Capture progress

Checks independent raster, logical-game and accepted-VBL counters. IRQ request
expiry and masked boot never confirm a pause. A recent source-qualified ACK,
no pending IRQ and a bounded quiet interval permit the IRQ-driven pause policy.
Old evidence expires after three running rasters; confirmed pauses retain it.
Tests cover long capture holds, unexpected IRQs, single stepping, unsupported
feedback, disabled policy, and reset/epoch invalidation without fake events.
