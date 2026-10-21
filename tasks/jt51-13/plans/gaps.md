# Consolidated implementation requirements

This inventory carries forward the six physically supported production-JT51
requirements from the [earlier measured inventory](../../jtcores-143/plans/gaps.md).
The replacement-history [results](../RESULTS.md) add finite history coverage
and one additional scoped low-release requirement. The latter has repeated
physical fade/production-hold observations, completed key-offs and adjacent
controls; unaligned whole-window level differences alone establish no cause.
Production remains `985a573dcfc1ff135553a39f7eae21d18ba57cbe`.

The priority order below groups output-visible failures for the single combined
implementation follow-up [jt51#14](http://gitea.jotego.es/jotego/jt51/issues/14).
It is an implementation work order, not a claim about shared internal causes.
The original six requirements retain their controls, scope and counterexamples;
the seventh is supported by the new [independent low-release review](low-release.md).

| Priority | Required behavior | Physical evidence and scope |
|---|---|---|
| 1 | Automatic CSM produces repeated output at the measured settings | All32 calibrated channel/operator routes;192 automatic PCB outputs repeat while corresponding JT51 outputs remain quiet. Selected256/512/1024-frame settings and AR30 controls. Exact pulse width, internal key simultaneity and IRQ are unobserved. |
| 2 | Effective AR30/31 does not take the production instant-attack branch | Four AR/KS configurations, adjacent controls, physical repetitions and phase/history variants. Do not extrapolate to every envelope rate. |
| 3 | Raw AR/D1R/D2R zero remains inhibited after key scaling | All-KS isolated holds, AR0 negatives and AR1 positives; native and longer windows establish observable leakage in production. Finite zero windows are not infinite-duration proofs. |
| 4 | D1L15 reaches the measured zero-PCM tail | All16 levels, three repetitions; levels0–14 have their earlier bounds, level15 PCB tail is exactly zero versus production±31. Nominal93dB comes from Yamaha documentation, not an analog measurement. |
| 5 | Preserve the measured D1/D2 attenuation granularity at rate12/KC4A/KS0 | Six PCB captures and separately qualified staircases resolve approximately0.09375dB versus production0.1875dB. Average duration can conceal the difference; no all-rate claim. |
| 6 | Timer status flag creation honors the measured enable/sticky-clear behavior | All16 control modes, three repetitions; seven disagreeing modes. This is a status-register requirement; physical IRQ was not observed. |
| 7 | Low rawRR0 release attenuates in the tested finite windows | Channel6/C2, ALG7/FB0, MUL8 at KS0/KC00 and KS3/KC04: PCB fades after key-off while production stays near full level through the late9.373s window. Both history conditions, three repetitions, both latches, exact-zero quiets and declining KC08/KC10 controls; key-off completion precedes all15 compared late blocks. No infinite hold, exact latency, one-EG-count rule or internal cause is inferred. |

The existing combined issue keeps the current architecture, groups coordinated
small changes where evidence supports them, and requires regression against
silicon-backed cases. No implementation or experimental patch is included here.
No additional implementation issue is needed. All seven requirements belong
together in the existing follow-up.

## Other classifications

| Observation | Classification and consequence |
|---|---|
| New controlled attack/release history windows beyond the scoped low-release gap | Finite public-output characterization; same EVENT bytecode between conditions, independently repeated controls, expanded timing and unknown accepted phase. Do not infer a one-EG-count priority rule or direct retained-counter state. |
| New natural ALG0 preserved versus isolated window | Finite mixed-program observation. Preserved EVENT has1200 writes/four key-ons/background; isolated EVENT has one selected program. Their level difference does not isolate history or routing. |
| Whole and fixed-block PCB/model energy differences | Descriptive public-output differences. Independent recording origins and CPU/model overhead prevent sample-error or universal agreement claims. |
| Odd-MUL pitch, joint-key relative phase and high-level mixing | Reproduced observations whose causes remain unclassified; previous evidence and bounds are retained. Model voting supplies no new physical diagnosis. |
| Small NE-on floor and reference carrier/pan exceptions | Existing output/reference differences with their original finite limits; no additional confirmed production requirement. |
| Exact original98880-write Rastan history | Input remains lost. The user explicitly accepted a newly recorded complete replacement. The new209206-write input is identified separately and archived with complete timestamps. |
| Earlier framing failures and short natural windows | Acquisition/finite-horizon limitations, retained with labels. They do not count as successful complete primary windows. |

The original input's recovery is no longer a prerequisite for the authorized
replacement campaign. Exact accepted-write phase, complete slowest-period and
arbitrary-history coverage remain scientific limits, carried into implementation
and regression work without being converted into universal conformance claims.
