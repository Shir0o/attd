// Convocation — Play Store marketing frames (1080x1920 viewport but rendered as 360x640 logical for the canvas)

const { Ic, Phone, Avatar } = window;

// We render at "design" scale: each frame is 540x960 (half of 1080x1920) for readability on the canvas.
// The bezel-phone inside is scaled.

function MarketingFrame({ bg, accent, eyebrow, title, sub, footer, children, theme = 'light' }) {
  return (
    <div style={{
      width: 540, height: 960, position: 'relative', overflow: 'hidden',
      background: bg, color: theme === 'dark' ? '#fff' : 'var(--ink)',
      fontFamily: 'var(--font-sans)',
      display: 'flex', flexDirection: 'column',
    }} data-theme={theme}>
      {/* Decorative serif glyph background */}
      <div className="t-display" aria-hidden style={{
        position: 'absolute', right: -80, top: -120,
        fontSize: 460, color: accent, opacity: 0.10, pointerEvents: 'none',
        fontVariationSettings: "'opsz' 144, 'SOFT' 100",
      }}>§</div>

      <div style={{ padding: '60px 50px 30px', position: 'relative', zIndex: 1 }}>
        {eyebrow && <div className="t-eyebrow" style={{ color: accent, fontSize: 14 }}>{eyebrow}</div>}
        <div className="t-display" style={{ fontSize: 60, marginTop: 10, lineHeight: 1.02, textWrap: 'balance' }}>{title}</div>
        {sub && <div style={{ marginTop: 14, fontSize: 19, lineHeight: 1.5, color: theme === 'dark' ? 'rgba(255,255,255,0.7)' : 'var(--ink-2)', maxWidth: 380 }}>{sub}</div>}
      </div>

      <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        {children}
      </div>

      {footer && (
        <div style={{ padding: '20px 50px 36px', textAlign: 'center', fontSize: 13, opacity: 0.6, fontFamily: 'var(--font-mono)' }}>{footer}</div>
      )}
    </div>
  );
}

// Mini phone preview helper (no real bezel, just app content scaled)
function MiniPhone({ children, theme = 'light', scale = 1, offsetX = 0, offsetY = 0, rotate = 0 }) {
  return (
    <div style={{
      position: 'absolute',
      width: 360, height: 760,
      left: '50%', bottom: 0,
      transform: `translate(calc(-50% + ${offsetX}px), ${offsetY}px) scale(${scale}) rotate(${rotate}deg)`,
      transformOrigin: 'center bottom',
      borderRadius: 36,
      background: theme === 'dark' ? '#1a151c' : '#dbd5e0',
      padding: 8, boxSizing: 'border-box',
      boxShadow: '0 40px 80px -20px rgba(0,0,0,0.3)',
    }}>
      <div data-theme={theme} style={{
        width: '100%', height: '100%', borderRadius: 30, overflow: 'hidden',
        background: theme === 'dark' ? 'oklch(16% 0.018 290)' : 'oklch(98.5% 0.006 295)',
        color: 'var(--ink)',
        position: 'relative',
      }}>
        {children}
      </div>
    </div>
  );
}

// 1. Hero — "Attendance, by hand."
function Promo1() {
  return (
    <MarketingFrame
      bg="oklch(96% 0.018 290)"
      accent="oklch(54% 0.18 285)"
      eyebrow="ATTENDANCE TRACKER"
      title="Attendance, by hand."
      sub="Take attendance with one thumb. Built for groups that meet often — and don't want a spreadsheet."
      footer="Free · No ads · Local-first"
    >
      <MiniPhone scale={0.95} offsetY={80}>
        <SwipePreview/>
      </MiniPhone>
    </MarketingFrame>
  );
}

function SwipePreview() {
  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 28 }}/>
      <div style={{ padding: '14px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Ic.close/>
        <div style={{ textAlign: 'center' }}>
          <div className="t-eyebrow" style={{ fontSize: 10 }}>Sunday Service</div>
          <div style={{ fontSize: 11, color: 'var(--ink-3)', marginTop: 2 }}>3 of 7</div>
        </div>
        <div style={{ fontSize: 13, color: 'var(--primary)', fontWeight: 500 }}>Done</div>
      </div>
      <div style={{ flex: 1, position: 'relative', padding: 24 }}>
        <div className="card" style={{ position: 'absolute', inset: 24, top: 12, padding: 24, transform: 'rotate(-4deg) translateX(-10px)', opacity: 0.5 }}>
          <Avatar letter="C" size={80}/>
        </div>
        <div className="card" style={{ position: 'absolute', inset: 24, top: 12, padding: 24, transform: 'rotate(6deg)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14 }}>
          <Avatar letter="B" size={100}/>
          <div className="t-display" style={{ fontSize: 32 }}>Bob Smith</div>
          <div className="t-eyebrow">Smith family</div>
          <div className="stamp stamp-present" style={{ position: 'absolute', top: 22, right: 22 }}>Present</div>
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 22, padding: '12px 0 24px' }}>
        <button style={{ width: 50, height: 50, borderRadius: '50%', background: 'var(--card-soft)', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-2)' }}><Ic.undo/></button>
        <button style={{ width: 60, height: 60, borderRadius: '50%', background: 'transparent', border: '2px solid var(--absent)', color: 'var(--absent)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{Ic.x(24)}</button>
        <button style={{ width: 72, height: 72, borderRadius: '50%', background: 'var(--present)', color: '#fff', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{Ic.check(28)}</button>
      </div>
    </div>
  );
}

// 2. List + family
function Promo2() {
  return (
    <MarketingFrame
      bg="oklch(95% 0.03 60)" // warm clay wash
      accent="oklch(58% 0.16 50)"
      eyebrow="FAMILIES · GROUPS"
      title="Group by family. Mark them all."
      sub="Track who came together. Bulk-mark whole families in one tap, then adjust individuals."
      footer="Smart defaults learn from past sessions"
    >
      <MiniPhone scale={0.92} offsetY={90}>
        <ListPreview/>
      </MiniPhone>
    </MarketingFrame>
  );
}

function ListPreview() {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 28 }}/>
      <div style={{ padding: '14px 18px' }}>
        <Ic.close/>
      </div>
      <div style={{ padding: '0 22px 12px' }}>
        <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>SUNDAY SERVICE</div>
        <div className="t-display" style={{ fontSize: 26, marginTop: 4 }}>Mark attendance</div>
        <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
          <div style={{ flex: 1, background: 'color-mix(in oklch, var(--present) 12%, transparent)', borderRadius: 12, padding: '8px 12px' }}>
            <div className="t-eyebrow" style={{ color: 'var(--present)', fontSize: 9 }}>PRESENT</div>
            <div className="t-num" style={{ fontSize: 22, color: 'var(--present)' }}>4</div>
          </div>
          <div style={{ flex: 1, background: 'color-mix(in oklch, var(--absent) 12%, transparent)', borderRadius: 12, padding: '8px 12px' }}>
            <div className="t-eyebrow" style={{ color: 'var(--absent)', fontSize: 9 }}>ABSENT</div>
            <div className="t-num" style={{ fontSize: 22, color: 'var(--absent)' }}>1</div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 12, justifyContent: 'space-between' }}>
          <div className="seg" style={{ fontSize: 11 }}>
            <button className="is-on" style={{ fontSize: 11, padding: '6px 10px' }}><Ic.family/> Family</button>
            <button style={{ fontSize: 11, padding: '6px 10px' }}><Ic.checks/> Status</button>
          </div>
          <button className="pill" style={{ fontSize: 11, padding: '7px 11px' }}>
            <Ic.checks/> All
          </button>
        </div>
      </div>
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 22px' }}>
        <div className="t-eyebrow" style={{ marginTop: 8, color: 'var(--ink-3)', fontSize: 9 }}>SMITH FAMILY · 2 OF 2</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: 'color-mix(in oklch, var(--present) 8%, var(--card))', borderRadius: 12, marginTop: 6 }}>
          <Avatar letter="A" tone="present" size={32}/>
          <div style={{ flex: 1, fontSize: 13, fontWeight: 500 }}>Alice Smith</div>
          <div className="toggle is-on"/>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: 'color-mix(in oklch, var(--present) 8%, var(--card))', borderRadius: 12, marginTop: 6 }}>
          <Avatar letter="B" tone="present" size={32}/>
          <div style={{ flex: 1, fontSize: 13, fontWeight: 500 }}>Bob Smith</div>
          <div className="toggle is-on"/>
        </div>
        <div className="t-eyebrow" style={{ marginTop: 10, color: 'var(--ink-3)', fontSize: 9 }}>JONES FAMILY · 0 OF 1</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: 'var(--card)', borderRadius: 12, marginTop: 6 }}>
          <Avatar letter="C" tone="absent" size={32}/>
          <div style={{ flex: 1, fontSize: 13, fontWeight: 500 }}>Carol Jones</div>
          <div className="toggle"/>
        </div>
      </div>
    </div>
  );
}

// 3. Regulars — celebrate the consistent members (no "streak" language)
function Promo3() {
  return (
    <MarketingFrame
      bg="oklch(93% 0.04 155)"
      accent="oklch(42% 0.16 155)"
      eyebrow="REGULARS"
      title="Who shows up."
      sub="Convocation quietly notices the members at 80%+ across your last 8 sessions — a gentle nudge to thank your most consistent."
      footer="Lives on your device · never shared"
    >
      <MiniPhone scale={0.92} offsetY={70}>
        <RegularsPreview/>
      </MiniPhone>
    </MarketingFrame>
  );
}

function RegularsPreview() {
  const rows = [
    { letter: 'D', name: 'Devon Jones',   family: 'Jones family',  hit: 8 },
    { letter: 'M', name: 'Mia Smith',     family: 'Smith family',  hit: 7 },
    { letter: 'R', name: 'Ruth Okafor',   family: 'Okafor family', hit: 7 },
    { letter: 'T', name: 'Theo Park',     family: 'Solo',          hit: 7 },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 28 }}/>
      <div style={{ padding: '14px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Ic.back/>
        <div className="t-eyebrow" style={{ fontSize: 9, color: 'var(--ink-3)' }}>SUNDAY SERVICE</div>
        <Ic.gear/>
      </div>
      <div style={{ padding: '4px 22px 0' }}>
        <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>REGULARS</div>
        <div className="t-display" style={{ fontSize: 28, marginTop: 4, lineHeight: 1.04 }}>The reliable few</div>
        <div style={{ fontSize: 11, color: 'var(--ink-3)', marginTop: 4 }}>Members at 80%+ across the last 8 sessions</div>
      </div>

      {/* Hero card */}
      <div style={{ margin: '16px 22px 0', padding: '14px 16px', borderRadius: 16, background: 'linear-gradient(135deg, color-mix(in oklch, var(--primary) 22%, transparent), color-mix(in oklch, var(--primary) 6%, transparent))', border: '1px solid color-mix(in oklch, var(--primary) 30%, transparent)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <Avatar letter="A" size={44}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--ink)' }}>Alice Smith</div>
            <div style={{ fontSize: 10, color: 'var(--ink-3)', marginTop: 2 }}>Smith family · highest attendance</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="t-num" style={{ fontSize: 30, color: 'var(--primary)', lineHeight: 0.95 }}>8<span style={{ fontSize: 14, opacity: 0.6 }}>/8</span></div>
            <div className="t-eyebrow" style={{ fontSize: 8, marginTop: 2 }}>SESSIONS</div>
          </div>
        </div>
        {/* Session-by-session ribbon: 8 dots, all filled for Alice */}
        <div style={{ display: 'flex', gap: 4, marginTop: 12 }}>
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} style={{ flex: 1, height: 6, borderRadius: 2, background: 'var(--primary)', opacity: 0.4 + (i / 8) * 0.6 }}/>
          ))}
        </div>
      </div>

      {/* Ranked list */}
      <div style={{ marginTop: 14, padding: '0 22px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {rows.map((r, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', background: 'var(--card-soft)', borderRadius: 12 }}>
            <div style={{ width: 18, fontSize: 11, color: 'var(--ink-3)', fontVariantNumeric: 'tabular-nums', textAlign: 'center' }}>{i + 2}</div>
            <Avatar letter={r.letter} size={28}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 12, fontWeight: 500, color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.name}</div>
              <div style={{ fontSize: 9, color: 'var(--ink-3)', marginTop: 1 }}>{r.family}</div>
            </div>
            {/* mini ribbon: 8 segments, `hit` of them filled */}
            <div style={{ display: 'flex', gap: 2, width: 56 }}>
              {Array.from({ length: 8 }).map((_, j) => (
                <div key={j} style={{ flex: 1, height: 5, borderRadius: 1.5, background: j < r.hit ? 'var(--primary)' : 'var(--hair)', opacity: j < r.hit ? 0.85 : 1 }}/>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// 7. Trends — session summary with sparkline (restored from archive)
function Promo7() {
  return (
    <MarketingFrame
      bg="oklch(26% 0.05 165)"
      accent="oklch(78% 0.10 165)"
      eyebrow="SESSION SUMMARY"
      title="Every Sunday, remembered."
      sub="See trends over months. Export to CSV. Sync to Google Drive — your account, never ours."
      footer="100% local · zero analytics"
      theme="dark"
    >
      <MiniPhone scale={0.92} offsetY={70} theme="dark">
        <SummaryPreview/>
      </MiniPhone>
    </MarketingFrame>
  );
}

function SummaryPreview() {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 28 }}/>
      <div style={{ padding: '14px 18px', display: 'flex', justifyContent: 'space-between' }}>
        <Ic.back/>
        <Ic.upload/>
      </div>
      <div style={{ padding: '4px 22px 0' }}>
        <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>SAVED · MAY 24</div>
        <div className="t-display" style={{ fontSize: 28, marginTop: 4 }}>Sunday Service</div>

        <div style={{ display: 'flex', marginTop: 18, gap: 0 }}>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow" style={{ color: 'var(--present)', fontSize: 9 }}>PRESENT</div>
            <div className="t-num" style={{ fontSize: 76, color: 'var(--present)', lineHeight: 0.95 }}>42</div>
            <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>93% of expected</div>
          </div>
          <div style={{ flex: 1, paddingLeft: 14, borderLeft: '1px solid var(--hair)' }}>
            <div className="t-eyebrow" style={{ color: 'var(--absent)', fontSize: 9 }}>ABSENT</div>
            <div className="t-num" style={{ fontSize: 76, color: 'var(--absent)', lineHeight: 0.95 }}>03</div>
            <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>↓ trending down</div>
          </div>
        </div>

        <div style={{ marginTop: 20, background: 'var(--card-soft)', borderRadius: 14, padding: '12px 14px' }}>
          <div className="t-eyebrow" style={{ fontSize: 9 }}>REGULARS · 80% IN LAST 8</div>
          <div style={{ fontSize: 14, fontWeight: 500, marginTop: 4 }}>Alice S., Ben K., Devon J. <span style={{ color: 'var(--ink-3)', fontWeight: 400 }}>+2</span></div>
        </div>

        {/* Sparkline mini chart */}
        <div style={{ marginTop: 14, display: 'flex', alignItems: 'flex-end', gap: 6, height: 70 }}>
          {[60, 75, 80, 65, 82, 90, 88, 92, 78, 85, 90, 93].map((v, i) => (
            <div key={i} style={{ flex: 1, background: 'var(--primary)', borderRadius: 3, height: `${v}%`, opacity: i === 11 ? 1 : 0.35 }}/>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 10, color: 'var(--ink-3)' }}>
          <span>12 weeks ago</span><span>Today</span>
        </div>
      </div>
    </div>
  );
}

// 4. Privacy / local-first
function Promo4() {
  return (
    <MarketingFrame
      bg="oklch(94% 0.04 285)"
      accent="oklch(38% 0.18 285)"
      eyebrow="LOCAL-FIRST"
      title="Your data. Your device."
      sub="Everything stays on your phone unless you sync to your own Google Drive. We don't run servers. We don't sell anything."
      footer="No analytics · No ads · Open source"
    >
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
        <div style={{
          width: 380, height: 380, borderRadius: '50%',
          background: 'radial-gradient(circle, color-mix(in oklch, var(--primary) 25%, transparent), transparent 70%)',
          position: 'absolute', bottom: -120,
        }}/>
        <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20, paddingBottom: 60 }}>
          <div style={{ width: 140, height: 140, borderRadius: 44, background: 'var(--card)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary)', boxShadow: '0 20px 60px -20px rgba(50,30,90,0.3)' }}>
            <svg width="72" height="72" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>
          </div>
          <div style={{ display: 'flex', gap: 12 }}>
            <PromoChip text="No ads"/>
            <PromoChip text="No tracking"/>
            <PromoChip text="Encrypted sync"/>
          </div>
        </div>
      </div>
    </MarketingFrame>
  );
}

function PromoChip({ text }) {
  return (
    <div style={{
      padding: '10px 18px', borderRadius: 999,
      background: 'var(--card)', color: 'var(--ink-2)',
      fontSize: 14, fontWeight: 500,
      boxShadow: '0 4px 16px -8px rgba(50,30,90,0.2)',
    }}>{text}</div>
  );
}

// 5. Quick start
function Promo5() {
  return (
    <MarketingFrame
      bg="oklch(98% 0.006 295)"
      accent="oklch(58% 0.16 50)"
      eyebrow="ONE MINUTE"
      title="Set up in 60 seconds."
      sub="Add members, create a recurring event, and start swiping. No accounts. No setup wizards."
      footer="Available on Android · iOS coming soon"
    >
      <div style={{ position: 'absolute', inset: 0, padding: '0 50px', display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 16 }}>
        {[
          { n: '01', t: 'Add your members', sub: 'Type names. Group into families.', icon: <Ic.people/> },
          { n: '02', t: 'Create an event', sub: 'Sunday 10:00. Weekly. Done.', icon: <Ic.clock/> },
          { n: '03', t: 'Take attendance', sub: 'Swipe — or tap to mark everyone.', icon: Ic.check(20) },
        ].map((s, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 20, padding: '18px 22px', background: 'var(--card)', borderRadius: 22, boxShadow: '0 8px 24px -12px rgba(50,30,90,0.15)' }}>
            <div className="t-num" style={{ fontSize: 44, color: 'var(--primary)', opacity: 0.4, width: 60 }}>{s.n}</div>
            <div style={{ flex: 1 }}>
              <div className="t-headline" style={{ fontSize: 22 }}>{s.t}</div>
              <div className="t-body" style={{ marginTop: 4 }}>{s.sub}</div>
            </div>
            <div style={{ width: 48, height: 48, borderRadius: 14, background: 'color-mix(in oklch, var(--primary) 14%, transparent)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{s.icon}</div>
          </div>
        ))}
      </div>
    </MarketingFrame>
  );
}

// 6. Beautiful empty state — dark
function Promo6() {
  return (
    <MarketingFrame
      bg="oklch(16% 0.018 290)"
      accent="oklch(76% 0.12 285)"
      eyebrow="DAY · NIGHT"
      title="At home in dark mode."
      sub="A soft aubergine that's easier on the eyes. The whole app, two faces."
      footer="System theme · or your choice"
      theme="dark"
    >
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: -40 }}>
        <MiniPhone theme="light" scale={0.7} offsetX={-110} rotate={-6}>
          <HubMini/>
        </MiniPhone>
        <MiniPhone theme="dark" scale={0.75} offsetX={110} rotate={4}>
          <HubMini dark/>
        </MiniPhone>
      </div>
    </MarketingFrame>
  );
}

function HubMini({ dark }) {
  return (
    <div style={{ height: '100%', padding: 14, display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 28 }}/>
      <div style={{ padding: '10px 6px 8px' }}>
        <div className="t-eyebrow" style={{ fontSize: 9 }}>SUNDAY · MAY 24</div>
        <div className="t-display" style={{ fontSize: 30, marginTop: 4 }}>Today</div>
      </div>
      <div className="card" style={{ padding: 16, marginTop: 6 }}>
        <span className="pill is-on" style={{ padding: '3px 8px', fontSize: 9 }}>TODAY · 10:00</span>
        <div className="t-display" style={{ fontSize: 28, marginTop: 12, color: 'var(--ink)' }}>Lord's Table</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 14 }}>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow" style={{ fontSize: 8 }}>EXPECTED</div>
            <div className="t-num" style={{ fontSize: 22, color: 'var(--ink)', marginTop: 2 }}>42</div>
          </div>
          <button className="btn btn-primary" style={{ padding: '8px 14px', fontSize: 12 }}>Start <Ic.play/></button>
        </div>
      </div>
      <div style={{ marginTop: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <span className="t-eyebrow" style={{ fontSize: 9 }}>UPCOMING</span>
        <span className="t-eyebrow" style={{ fontSize: 9, color: 'var(--ink-4)' }}>3 · THIS WEEK</span>
      </div>
      <div className="card-soft" style={{ padding: '10px 12px', marginTop: 8, display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 30, textAlign: 'center' }}>
          <div className="t-eyebrow" style={{ fontSize: 8 }}>SUN</div>
          <div className="t-num" style={{ fontSize: 16, color: 'var(--ink)', lineHeight: 1 }}>24</div>
        </div>
        <div style={{ flex: 1, fontSize: 12, fontWeight: 500 }}>Sunday Service</div>
        <span className="t-eyebrow" style={{ fontSize: 8, color: 'var(--ink-3)' }}>6:00 PM</span>
      </div>
      <div className="card-soft" style={{ padding: '10px 12px', marginTop: 6, display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 30, textAlign: 'center' }}>
          <div className="t-eyebrow" style={{ fontSize: 8 }}>WED</div>
          <div className="t-num" style={{ fontSize: 16, color: 'var(--ink)', lineHeight: 1 }}>27</div>
        </div>
        <div style={{ flex: 1, fontSize: 12, fontWeight: 500 }}>Mid-week Study</div>
        <span className="t-eyebrow" style={{ fontSize: 8, color: 'var(--ink-3)' }}>7:00 PM</span>
      </div>
    </div>
  );
}

Object.assign(window, { Promo1, Promo2, Promo3, Promo4, Promo5, Promo6, Promo7 });
