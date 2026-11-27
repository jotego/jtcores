<!-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
     SPDX-License-Identifier: GPL-3.0-or-later
     Date: 24-10-2026 -->

# Pending schematic checks

- Confirm 2E/2F address digits, /ZM(*) and /ZRB sources, write/read qualifiers and address mirrors.
- Trace remaining CPU memory selects, RAM1S/RAM2S and address muxes 3H/2H.
- Complete source-C counter controls; identify the lower counter beside 8J.
- Trace 8E, 8N and 9O data sources to establish graphics-layer and pixel-bit identities.
- Complete 4M/4N/4O/5N local-bus controls, 4O direction/enable and 5N capture pins.
- Establish CD validity and counter/RAM/9D capture order around /MCLK; compare physical banks with the generic object buffer.
- Confirm PROM output interconnections, individual RGB resistor routes and disabled-output behaviour.
- Confirm PAL pin 11 label/bar, supply routes and P ties; Frisky 2D preset ties remain scan-derived.
- Identify fitted PAL/2D families and loaded H2 clock parts; actual request/release delay needs board waveforms.
- Confirm remaining vertical-counter feedback and clear ties; finish HS/VS output routing.
- Confirm Z80/AY global-reset endpoints and the remaining NE555 AC-monitor components.
- Identify watchdog service contact and any external AY port-B pull-ups.
- Trace audio latch 2C clock/clear and exact 4066 package-unit assignments.
- Assign R40/R41 to their audio paths; identify the extra 100k bias resistor and empty R30/R35 footprints.
- Confirm feedback-cap units and amplifier input-cap value.
- Identify the amplifier package/pins 5/8; verify C5/C6 output junctions and supply bypass C8.
