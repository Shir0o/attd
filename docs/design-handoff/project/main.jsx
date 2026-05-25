// Convocation — main entry

const {
  DesignCanvas, DCSection, DCArtboard, DCPostIt,
  TweaksPanel, useTweaks, TweakSection, TweakRadio, TweakColor,
  Phone, Ic,
  HubScreen, HubEmpty, ListScreen, MarkEveryoneSheet,
  FamiliesScreen, FamilyEditScreen, SummaryScreen,
  SuggestFamiliesScreen, FamiliesWithSuggestionBanner,
  OnboardingScreen, AddEventScreen, SettingsScreen, MembersScreen,
  SwipeDeckA, SwipeDeckB, SwipeDeckC, QuickList,
  Promo1, Promo2, Promo3, Promo4, Promo5, Promo6, Promo7,
} = window;

// Helper (NOT a component — DesignCanvas filters children by type === DCArtboard,
// so any wrapper component would be silently dropped).
function phoneArtboard({ id, label, theme = 'light', accent = 'violet', children }) {
  return (
    <DCArtboard id={id} label={label} width={420} height={900}>
      <Phone theme={theme}>
        <div data-accent={accent} style={{ width: '100%', height: '100%' }}>
          {children}
        </div>
      </Phone>
    </DCArtboard>
  );
}

function App() {
  const [t, setTweak] = useTweaks(/*EDITMODE-BEGIN*/{
    "accent": "violet",
    "density": "comfortable"
  }/*EDITMODE-END*/);
  const accent = t.accent || 'violet';

  return (
    <div data-accent={accent} style={{ height: '100vh', overflow: 'hidden' }}>
      <DesignCanvas>
        {/* ── 0. Cover / intro ───────────────────────────── */}
        <DCSection id="cover" title="Convocation" subtitle="A redesign + app-store kit for Attendance Tracker · Day &amp; Night themes · Fraunces × Geist">
          <DCArtboard id="north-star" label="Direction" width={520} height={620}>
            <CoverCard/>
          </DCArtboard>
          <DCArtboard id="palette" label="Colors" width={420} height={620}>
            <PaletteCard/>
          </DCArtboard>
          <DCArtboard id="type" label="Typography" width={460} height={620}>
            <TypeCard/>
          </DCArtboard>
        </DCSection>

        {/* ── 1. Hub ─────────────────────────────────────── */}
        <DCSection id="hub" title="01 · Hub" subtitle="Editorial date header, hero event card, multi-event roll. Day &amp; Night.">
          {phoneArtboard({ id: 'hub-light', label: 'Hub · Day', theme: 'light', accent, children: <HubScreen theme="light"/> })}
          {phoneArtboard({ id: 'hub-dark', label: 'Hub · Night', theme: 'dark', accent, children: <HubScreen theme="dark"/> })}
          {phoneArtboard({ id: 'hub-empty', label: 'Hub · Empty', theme: 'light', accent, children: <HubEmpty theme="light"/> })}
          {phoneArtboard({ id: 'hub-empty-dark', label: 'Hub · Empty · Night', theme: 'dark', accent, children: <HubEmpty theme="dark"/> })}
        </DCSection>

        {/* ── 2. Swipe deck — the centerpiece ────────────── */}
        <DCSection id="swipe" title="02 · Quick Marking" subtitle="The marquee interaction. Try the gestures on Deck A — that's the one we're shipping.">
          {phoneArtboard({ id: 'deck-a-light', label: 'A · Refined stack ★ shipping', theme: 'light', accent, children: <SwipeDeckA theme="light"/> })}
          {phoneArtboard({ id: 'deck-a-dark', label: 'A · Refined · Night ★ shipping', theme: 'dark', accent, children: <SwipeDeckA theme="dark"/> })}
          {phoneArtboard({ id: 'quick-list', label: 'List view · quick-tap', theme: 'light', accent, children: <QuickList theme="light"/> })}
          {phoneArtboard({ id: 'quick-list-dark', label: 'List view · Night', theme: 'dark', accent, children: <QuickList theme="dark"/> })}
        </DCSection>

        {/* ── 3. List view + new toggles ─────────────────── */}
        <DCSection id="list" title="03 · List view + new toggle UX" subtitle="Replaces 2 chip-pills + 3-dot kebab with a single 3-mode segmented control + visible bulk pill.">
          {phoneArtboard({ id: 'list-fam', label: 'List · By family', theme: 'light', accent, children: <ListScreen theme="light" mode="family"/> })}
          {phoneArtboard({ id: 'list-stat', label: 'List · By status', theme: 'light', accent, children: <ListScreen theme="light" mode="status"/> })}
          {phoneArtboard({ id: 'list-dark', label: 'List · Night', theme: 'dark', accent, children: <ListScreen theme="dark" mode="family"/> })}
          {phoneArtboard({ id: 'bulk-sheet', label: 'Bulk attendance sheet', theme: 'light', accent, children: <MarkEveryoneSheet theme="light"/> })}
          {phoneArtboard({ id: 'bulk-sheet-dark', label: 'Bulk attendance · Night', theme: 'dark', accent, children: <MarkEveryoneSheet theme="dark"/> })}
        </DCSection>

        {/* ── 4. NEW: Family management ──────────────────── */}
        <DCSection id="family" title="04 · NEW Family management" subtitle="Currently unreachable in shipping nav. A first-class screen for adding, editing, splitting families.">
          {phoneArtboard({ id: 'fam-banner', label: 'Discovery · Suggest banner', theme: 'light', accent, children: <FamiliesWithSuggestionBanner theme="light"/> })}
          {phoneArtboard({ id: 'fam-banner-dark', label: 'Discovery · Suggest · Night', theme: 'dark', accent, children: <FamiliesWithSuggestionBanner theme="dark"/> })}
          {phoneArtboard({ id: 'fam-suggest', label: 'Suggest families · review', theme: 'light', accent, children: <SuggestFamiliesScreen theme="light"/> })}
          {phoneArtboard({ id: 'fam-suggest-dark', label: 'Suggest · Night', theme: 'dark', accent, children: <SuggestFamiliesScreen theme="dark"/> })}
          {phoneArtboard({ id: 'families-light', label: 'Families · index', theme: 'light', accent, children: <FamiliesScreen theme="light"/> })}
          {phoneArtboard({ id: 'families-dark', label: 'Families · Night', theme: 'dark', accent, children: <FamiliesScreen theme="dark"/> })}
          {phoneArtboard({ id: 'family-edit', label: 'Family · edit', theme: 'light', accent, children: <FamilyEditScreen theme="light"/> })}
          {phoneArtboard({ id: 'family-edit-dark', label: 'Family · edit · Night', theme: 'dark', accent, children: <FamilyEditScreen theme="dark"/> })}
        </DCSection>

        {/* ── 5. Session summary ─────────────────────────── */}
        <DCSection id="summary" title="05 · Session Summary" subtitle="Editorial split (Present / Absent), regulars, sparklines. Single 3-mode segmented control.">
          {phoneArtboard({ id: 'summary-light', label: 'Summary · Day', theme: 'light', accent, children: <SummaryScreen theme="light"/> })}
          {phoneArtboard({ id: 'summary-dark', label: 'Summary · Night', theme: 'dark', accent, children: <SummaryScreen theme="dark"/> })}
        </DCSection>

        {/* ── 6. Onboarding ──────────────────────────────── */}
        <DCSection id="onboarding" title="06 · Onboarding" subtitle="Four editorial postcards. Asymmetric, bleeding illustrations.">
          {phoneArtboard({ id: 'ob1', label: '01 · Quick Marking', theme: 'light', accent, children: <OnboardingScreen step={1} theme="light"/> })}
          {phoneArtboard({ id: 'ob1-dark', label: '01 · Quick Marking · Night', theme: 'dark', accent, children: <OnboardingScreen step={1} theme="dark"/> })}
          {phoneArtboard({ id: 'ob2', label: '02 · History', theme: 'light', accent, children: <OnboardingScreen step={2} theme="light"/> })}
          {phoneArtboard({ id: 'ob2-dark', label: '02 · History · Night', theme: 'dark', accent, children: <OnboardingScreen step={2} theme="dark"/> })}
          {phoneArtboard({ id: 'ob3', label: '03 · Families', theme: 'light', accent, children: <OnboardingScreen step={3} theme="light"/> })}
          {phoneArtboard({ id: 'ob3-dark', label: '03 · Families · Night', theme: 'dark', accent, children: <OnboardingScreen step={3} theme="dark"/> })}
          {phoneArtboard({ id: 'ob4', label: '04 · Local-first', theme: 'light', accent, children: <OnboardingScreen step={4} theme="light"/> })}
          {phoneArtboard({ id: 'ob4-dark', label: '04 · Local-first · Night', theme: 'dark', accent, children: <OnboardingScreen step={4} theme="dark"/> })}
        </DCSection>

        {/* ── 7. Forms + Settings + Members ──────────────── */}
        <DCSection id="forms" title="07 · Forms, Members, Settings">
          {phoneArtboard({ id: 'addevent', label: 'Add event', theme: 'light', accent, children: <AddEventScreen theme="light"/> })}
          {phoneArtboard({ id: 'addevent-dark', label: 'Add event · Night', theme: 'dark', accent, children: <AddEventScreen theme="dark"/> })}
          {phoneArtboard({ id: 'members', label: 'Members', theme: 'light', accent, children: <MembersScreen theme="light"/> })}
          {phoneArtboard({ id: 'members-dark', label: 'Members · Night', theme: 'dark', accent, children: <MembersScreen theme="dark"/> })}
          {phoneArtboard({ id: 'settings', label: 'Settings', theme: 'light', accent, children: <SettingsScreen theme="light"/> })}
          {phoneArtboard({ id: 'settings-dark', label: 'Settings · Night', theme: 'dark', accent, children: <SettingsScreen theme="dark"/> })}
        </DCSection>

        {/* ── ARCHIVE ─────────────────────────────────────
            HANDOFF NOTE — for Claude Code / any engineer reading this:
            The artboards in the "Archive" section below are EXPLORED-AND-REJECTED
            design directions. They are kept in the file for reference only.
            DO NOT IMPLEMENT, DO NOT BUILD, DO NOT PORT.
            Ship Deck A (SwipeDeckA) from section 02 instead.
        ───────────────────────────────────────────────── */}
        <DCSection
          id="archive"
          title="✕ Archive · DO NOT BUILD"
          subtitle="Rejected directions kept for reference. Claude Code / engineers: skip this section — ship Deck A from §02 instead."
        >
          {phoneArtboard({ id: 'archive-deck-b', label: 'B · Postcard — REJECTED', theme: 'light', accent, children: <ArchivedWrap reason="Postcard framing feels heavy and ceremonial; competes with the swipe gesture."><SwipeDeckB theme="light"/></ArchivedWrap> })}
          {phoneArtboard({ id: 'archive-deck-c', label: 'C · Ribbon carousel — REJECTED', theme: 'light', accent, children: <ArchivedWrap reason="Horizontal ribbon obscures the next card and slows down marking."><SwipeDeckC theme="light"/></ArchivedWrap> })}
        </DCSection>

        {/* ── 8. Play Store screenshots ──────────────────── */}
        <DCSection id="promo" title="08 · Play Store screenshots" subtitle="1080×1920 — rendered here at 540×960. Hand-off as PNGs.">
          <DCArtboard id="p1" label="1 · Hero" width={540} height={960}><div data-accent={accent}><Promo1/></div></DCArtboard>
          <DCArtboard id="p2" label="2 · Families" width={540} height={960}><div data-accent={accent}><Promo2/></div></DCArtboard>
          <DCArtboard id="p3" label="3 · Regulars" width={540} height={960}><div data-accent={accent}><Promo3/></div></DCArtboard>
          <DCArtboard id="p4" label="4 · Privacy" width={540} height={960}><div data-accent={accent}><Promo4/></div></DCArtboard>
          <DCArtboard id="p5" label="5 · Quick start" width={540} height={960}><div data-accent={accent}><Promo5/></div></DCArtboard>
          <DCArtboard id="p6" label="6 · Day &amp; Night" width={540} height={960}><div data-accent={accent}><Promo6/></div></DCArtboard>
          <DCArtboard id="p7" label="7 · Trends" width={540} height={960}><div data-accent={accent}><Promo7/></div></DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Brand">
          <TweakRadio
            label="Accent"
            value={t.accent || 'violet'}
            onChange={v => setTweak('accent', v)}
            options={['violet', 'forest', 'sea', 'clay']}
          />
        </TweakSection>
        <TweakSection title="About">
          <div style={{ fontSize: 12, color: 'rgba(0,0,0,0.6)', lineHeight: 1.5 }}>
            Drag any swipe card. Tap ↻ to rewind. Click section titles to rename. ↗ on a card opens it fullscreen with ←/→/Esc.
          </div>
        </TweakSection>
      </TweaksPanel>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ArchivedWrap — overlays an "ARCHIVED — DO NOT BUILD" stamp on
// any rejected design direction. Kept in the file for reference
// only; explicit signal to Claude Code / engineers to skip these.
// ─────────────────────────────────────────────────────────────
function ArchivedWrap({ reason, children }) {
  return (
    <div
      data-archived="true"
      data-do-not-implement="true"
      data-handoff-note="ARCHIVED — rejected design direction. Do not build this. Ship SwipeDeckA from section 02 instead."
      style={{ position: 'relative', width: '100%', height: '100%' }}
    >
      <div style={{ width: '100%', height: '100%', filter: 'grayscale(0.55)', opacity: 0.78 }}>
        {children}
      </div>
      {/* Diagonal hatching to make 'archived' read instantly */}
      <div aria-hidden style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        background: 'repeating-linear-gradient(135deg, rgba(20,20,28,0.06) 0 14px, rgba(20,20,28,0) 14px 28px)',
      }}/>
      {/* Stamp */}
      <div style={{
        position: 'absolute', top: 14, left: 14, right: 14,
        display: 'flex', flexDirection: 'column', gap: 6,
        padding: '10px 12px',
        background: 'oklch(98% 0.012 25)',
        border: '1.5px solid oklch(58% 0.20 25)',
        borderRadius: 10,
        color: 'oklch(38% 0.18 25)',
        fontFamily: 'var(--font-sans, system-ui)',
        boxShadow: '0 6px 20px -8px rgba(0,0,0,0.25)',
        pointerEvents: 'none',
        zIndex: 5,
      }}>
        <div style={{
          fontSize: 10, fontWeight: 700, letterSpacing: '0.14em',
          textTransform: 'uppercase', color: 'oklch(48% 0.20 25)',
        }}>
          ✕ Archived · do not build
        </div>
        {reason ? (
          <div style={{ fontSize: 11, lineHeight: 1.35, color: 'oklch(32% 0.04 25)' }}>
            {reason}
          </div>
        ) : null}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Cover, Palette, Typography cards
// ─────────────────────────────────────────────────────────────
function CoverCard() {
  return (
    <div style={{
      width: '100%', height: '100%', padding: 36,
      background: 'oklch(98.5% 0.006 295)', color: 'oklch(22% 0.025 285)',
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      position: 'relative', overflow: 'hidden',
      fontFamily: 'var(--font-sans)',
    }}>
      <div className="t-display" aria-hidden style={{ position: 'absolute', top: -90, right: -60, fontSize: 420, color: 'oklch(54% 0.18 285)', opacity: 0.08, lineHeight: 1, fontVariationSettings: "'opsz' 144, 'SOFT' 100" }}>§</div>
      <div>
        <div className="t-eyebrow">CONVOCATION · CASE STUDY</div>
        <div className="t-display" style={{ fontSize: 76, lineHeight: 0.95, marginTop: 18 }}>Attendance,<br/>by hand.</div>
        <div className="t-body" style={{ fontSize: 17, marginTop: 22, maxWidth: 380 }}>
          A redesign of <strong>Attendance Tracker</strong> that trades spreadsheet feel for editorial warmth — without losing the speed-swipe core. New: family management, single 3-mode roster control, bulk-mark sheet, day &amp; night, Play Store kit.
        </div>
      </div>
      <div style={{ display: 'flex', gap: 16, marginTop: 24, flexWrap: 'wrap' }}>
        <Badge>Fraunces × Geist</Badge>
        <Badge>OKLCH palette</Badge>
        <Badge>Day &amp; Night</Badge>
        <Badge>9 redesigned screens</Badge>
        <Badge>6 store promos</Badge>
      </div>
    </div>
  );
}

function Badge({ children }) {
  return (
    <span style={{
      padding: '8px 14px', borderRadius: 999, background: 'oklch(95.5% 0.016 288)',
      fontSize: 12, fontWeight: 500, color: 'oklch(40% 0.020 285)',
      letterSpacing: '0.04em', textTransform: 'uppercase',
    }}>{children}</span>
  );
}

function PaletteCard() {
  const groups = [
    { name: 'Violet · brand', colors: [
      ['Wash', 'oklch(94% 0.04 285)'], ['Soft', 'oklch(76% 0.10 285)'], ['Primary', 'oklch(54% 0.18 285)'], ['Deep', 'oklch(38% 0.18 285)'],
    ]},
    { name: 'Clay · secondary', colors: [
      ['Wash', 'oklch(95% 0.03 60)'], ['Light', 'oklch(82% 0.08 55)'], ['Clay', 'oklch(72% 0.12 55)'], ['Deep', 'oklch(58% 0.16 50)'],
    ]},
    { name: 'Coral · absent', colors: [
      ['Wash', 'oklch(94% 0.04 25)'], ['Light', 'oklch(80% 0.10 25)'], ['Coral', 'oklch(68% 0.18 25)'], ['Deep', 'oklch(52% 0.20 25)'],
    ]},
    { name: 'Day · ink', colors: [
      ['Bg', 'oklch(98.5% 0.006 295)'], ['Card-soft', 'oklch(95.5% 0.016 288)'], ['Ink-3', 'oklch(60% 0.015 285)'], ['Ink', 'oklch(22% 0.025 285)'],
    ]},
    { name: 'Night · ink', colors: [
      ['Bg', 'oklch(16% 0.018 290)'], ['Card', 'oklch(22% 0.024 290)'], ['Ink-3', 'oklch(62% 0.020 285)'], ['Ink', 'oklch(96% 0.008 285)'],
    ]},
  ];
  return (
    <div style={{ width: '100%', height: '100%', padding: 28, background: '#fff', fontFamily: 'var(--font-sans)', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div>
        <div className="t-eyebrow">PALETTE · OKLCH</div>
        <div className="t-headline" style={{ fontSize: 26, marginTop: 6 }}>Soft, tonal, intentional.</div>
      </div>
      {groups.map((g, i) => (
        <div key={i}>
          <div style={{ fontSize: 11, color: 'oklch(60% 0.015 285)', fontWeight: 500, letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 6 }}>{g.name}</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
            {g.colors.map(([name, c], j) => (
              <div key={j} style={{ borderRadius: 10, overflow: 'hidden' }}>
                <div style={{ height: 50, background: c }}/>
                <div style={{ padding: '6px 8px', fontSize: 10, color: 'oklch(40% 0.020 285)' }}>{name}</div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function TypeCard() {
  return (
    <div style={{ width: '100%', height: '100%', padding: 32, background: 'oklch(96% 0.012 290)', fontFamily: 'var(--font-sans)', color: 'oklch(22% 0.025 285)', display: 'flex', flexDirection: 'column', gap: 22 }}>
      <div>
        <div className="t-eyebrow">TYPE PAIRING</div>
        <div className="t-headline" style={{ fontSize: 26, marginTop: 6 }}>Editorial × utilitarian.</div>
      </div>
      <div>
        <div style={{ fontSize: 10, color: 'oklch(60% 0.015 285)', fontWeight: 500, letterSpacing: '0.08em', textTransform: 'uppercase' }}>FRAUNCES · DISPLAY</div>
        <div className="t-display" style={{ fontSize: 80, lineHeight: 0.95, marginTop: 4 }}>Aa Æ §</div>
        <div className="t-display" style={{ fontSize: 28, marginTop: 8, color: 'oklch(40% 0.020 285)' }}>Attendance, by hand.</div>
      </div>
      <div>
        <div style={{ fontSize: 10, color: 'oklch(60% 0.015 285)', fontWeight: 500, letterSpacing: '0.08em', textTransform: 'uppercase' }}>GEIST · UI</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginTop: 4 }}>
          <div style={{ fontSize: 38, fontWeight: 300 }}>Aa</div>
          <div style={{ fontSize: 38, fontWeight: 500 }}>Aa</div>
          <div style={{ fontSize: 38, fontWeight: 700 }}>Aa</div>
        </div>
        <div style={{ fontSize: 14, marginTop: 8, color: 'oklch(40% 0.020 285)' }}>Mark attendance — by family, by status, or A–Z.</div>
      </div>
      <div>
        <div style={{ fontSize: 10, color: 'oklch(60% 0.015 285)', fontWeight: 500, letterSpacing: '0.08em', textTransform: 'uppercase' }}>NUMBERS · FRAUNCES TNUM</div>
        <div className="t-num" style={{ fontSize: 56, color: 'oklch(54% 0.18 285)', display: 'flex', gap: 16, marginTop: 4 }}>
          <span>42</span>
          <span style={{ color: 'oklch(68% 0.18 25)' }}>03</span>
          <span style={{ color: 'oklch(58% 0.16 50)' }}>14</span>
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
