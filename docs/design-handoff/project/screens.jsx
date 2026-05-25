// Convocation — screens (Hub, List, Families, Summary, Onboarding, Settings, AddEvent, Members)

const { Ic, Phone, StatusBar, NavPill, Avatar, DayChip } = window;

// ─────────────────────────────────────────────────────────────
// Hub — redesigned: editorial date header, "next" pulse, multi-event grid
// ─────────────────────────────────────────────────────────────
function HubScreen({ events = SAMPLE_EVENTS, theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar />
      <div className="app-header">
        <div>
          <div className="t-eyebrow" style={{ color: 'var(--ink-3)' }}>Sunday · May 24</div>
          <div className="t-display" style={{ fontSize: 30, color: 'var(--ink)', marginTop: 4 }}>Today</div>
        </div>
        <button className="icon-btn"><Ic.gear/></button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 18px 100px' }}>
        {/* "Up next" card — large, anchored, with start affordance */}
        {events.length > 0 && (
          <div className="card" style={{ padding: 22, marginTop: 10, position: 'relative', overflow: 'hidden' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="pill is-on" style={{ padding: '4px 10px', fontSize: 11, letterSpacing: '0.12em' }}>TODAY · 10:00</span>
              <button className="icon-btn" style={{ width: 32, height: 32, marginLeft: 'auto' }}><Ic.moreV/></button>
            </div>
            <div className="t-headline" style={{ fontSize: 34, marginTop: 16, color: 'var(--ink)' }}>{events[0].name}</div>
            <div style={{ display: 'flex', gap: 6, marginTop: 16 }}>
              {['S','M','T','W','T','F','S'].map((d,i) => <DayChip key={i} day={d} active={events[0].days?.includes(i)}/>)}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 22 }}>
              <div style={{ flex: 1 }}>
                <div className="t-eyebrow">Expected</div>
                <div className="t-num" style={{ fontSize: 28, color: 'var(--ink)' }}>42</div>
              </div>
              <div style={{ flex: 1 }}>
                <div className="t-eyebrow">Last week</div>
                <div className="t-num" style={{ fontSize: 28, color: 'var(--ink-2)' }}>38<span style={{ fontSize: 14, color: 'var(--ink-3)', marginLeft: 4, fontFamily: 'var(--font-sans)' }}>· 90%</span></div>
              </div>
              <button className="btn btn-primary" style={{ padding: '14px 22px' }}>
                Start <Ic.play/>
              </button>
            </div>
            {/* Decorative serif glyph — adds editorial luxury */}
            <div className="t-display" style={{
              position: 'absolute', right: -20, bottom: -50, fontSize: 200,
              color: 'var(--primary)', opacity: 0.06, pointerEvents: 'none',
            }}>§</div>
          </div>
        )}

        {/* Upcoming events */}
        <div style={{ marginTop: 28, marginBottom: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <div className="t-eyebrow">Upcoming</div>
          <div className="t-eyebrow" style={{ color: 'var(--ink-4)' }}>{events.length - 1} · this week</div>
        </div>
        {events.slice(1).map((ev, i) => <EventRow key={i} ev={ev}/>)}
      </div>

      <button className="fab">{Ic.plus(26)}</button>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function EventRow({ ev }) {
  return (
    <div className="card-soft" style={{ padding: '14px 16px', marginBottom: 10, display: 'flex', alignItems: 'center', gap: 14 }}>
      <div style={{ width: 44, textAlign: 'center' }}>
        <div className="t-eyebrow">{ev.dayLabel}</div>
        <div className="t-num" style={{ fontSize: 24, lineHeight: 1, color: 'var(--ink)' }}>{ev.dateNum}</div>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{ev.name}</div>
        <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 6 }}>
          <Ic.clock/> {ev.time}
        </div>
      </div>
      {ev.taken ? (
        <span className="pill" style={{ padding: '6px 12px', fontSize: 11 }}>
          {Ic.check(14)} Taken
        </span>
      ) : (
        <span className="t-eyebrow" style={{ color: 'var(--ink-3)' }}>{ev.dow}</span>
      )}
    </div>
  );
}

const SAMPLE_EVENTS = [
  { name: "Lord's Table", days: [1, 3], time: '10:00 AM', dateNum: '24', dayLabel: 'TODAY', dow: '', taken: false },
  { name: 'Sunday Service', dateNum: '24', dayLabel: 'SUN', time: '6:00 PM', dow: 'SUN', taken: false },
  { name: 'Mid-week Study', dateNum: '27', dayLabel: 'WED', time: '7:00 PM', dow: 'WED', taken: false },
  { name: 'Choir', dateNum: '28', dayLabel: 'THU', time: '7:30 PM', dow: 'THU', taken: true },
];

// ─────────────────────────────────────────────────────────────
// Hub — Empty state (new direction)
// ─────────────────────────────────────────────────────────────
function HubEmpty({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <div className="t-display" style={{ fontSize: 26, color: 'var(--ink)' }}>Today</div>
        <button className="icon-btn"><Ic.gear/></button>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 36px', textAlign: 'center', gap: 18 }}>
        {/* serif decorative number */}
        <div style={{ position: 'relative' }}>
          <span className="t-num" style={{ fontSize: 180, color: 'var(--primary)', opacity: 0.10, fontVariationSettings: "'opsz' 144" }}>0</span>
          <span className="t-eyebrow" style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', color: 'var(--ink-3)' }}>events</span>
        </div>
        <div className="t-headline" style={{ fontSize: 28, color: 'var(--ink)' }}>Nothing on the calendar yet.</div>
        <div className="t-body" style={{ maxWidth: 280 }}>Create your first event to start taking attendance. It only takes a moment.</div>
        <button className="btn btn-primary" style={{ marginTop: 8 }}>{Ic.plus(18)} New event</button>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// List view — redesigned toggles + mark-everyone UX
// ─────────────────────────────────────────────────────────────
function ListScreen({ theme = 'light', mode = 'family' /* family | status */ }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header" style={{ padding: '12px 18px 6px' }}>
        <button className="icon-btn"><Ic.close/></button>
        <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 8 }}>
          <button className="btn btn-ghost" style={{ padding: '8px 14px' }}>Done</button>
          <button className="icon-btn"><Ic.personAdd/></button>
        </div>
      </div>

      {/* Roster header with single elegant control set */}
      <div style={{ padding: '8px 18px 0' }}>
        <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>Sunday Service · 10:00</div>
        <div className="t-headline" style={{ fontSize: 26, color: 'var(--ink)', marginTop: 4 }}>Mark attendance</div>

        {/* Stats strip — replaces the "Present / Absent" 3/2 block */}
        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <StatChip label="Present" value="3" tone="present"/>
          <StatChip label="Absent" value="2" tone="absent"/>
          <StatChip label="Total" value="5" tone="neutral"/>
        </div>

        {/* Search */}
        <div style={{ marginTop: 16, background: 'var(--card-soft)', borderRadius: 14, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10, color: 'var(--ink-3)' }}>
          <Ic.search/>
          <span style={{ fontSize: 14 }}>Search by name or family</span>
        </div>

        {/* NEW: segmented control + bulk action button — replaces 2 chip-pills + kebab */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 14, justifyContent: 'space-between' }}>
          <div className="seg">
            <button className={mode === 'family' ? 'is-on' : ''}><Ic.family/> Family</button>
            <button className={mode === 'status' ? 'is-on' : ''}><Ic.checks/> Status</button>
          </div>
          <button className="pill" style={{ padding: '9px 14px' }}>
            <Ic.checks/> All
          </button>
        </div>
      </div>

      {/* Members */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '18px 18px 80px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        {mode === 'family' && (
          <>
            <SectionLabel>Smith Family · 2 of 2</SectionLabel>
            <PersonRow letter="A" name="Alice Smith" state="present"/>
            <PersonRow letter="B" name="Bob Smith" state="present"/>
            <SectionLabel>Jones Family · 0 of 1</SectionLabel>
            <PersonRow letter="C" name="Carol Jones" state="absent"/>
            <SectionLabel>Solo · 2 members</SectionLabel>
            <PersonRow letter="D" name="Dan Solo" state="present"/>
            <PersonRow letter="E" name="Eve Lonely" state="absent"/>
          </>
        )}
        {mode === 'status' && (
          <>
            <SectionLabel tone="present">Present · 3</SectionLabel>
            <PersonRow letter="A" name="Alice Smith" state="present"/>
            <PersonRow letter="B" name="Bob Smith" state="present"/>
            <PersonRow letter="D" name="Dan Solo" state="present"/>
            <SectionLabel tone="absent">Absent · 2</SectionLabel>
            <PersonRow letter="C" name="Carol Jones" state="absent"/>
            <PersonRow letter="E" name="Eve Lonely" state="absent"/>
          </>
        )}
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function StatChip({ label, value, tone }) {
  const colors = {
    present: { bg: 'color-mix(in oklch, var(--present) 12%, transparent)', fg: 'var(--present)' },
    absent: { bg: 'color-mix(in oklch, var(--absent) 12%, transparent)', fg: 'var(--absent)' },
    neutral: { bg: 'var(--card-soft)', fg: 'var(--ink-2)' },
  }[tone];
  return (
    <div style={{ flex: 1, background: colors.bg, borderRadius: 16, padding: '12px 14px' }}>
      <div className="t-eyebrow" style={{ color: colors.fg, opacity: 0.8 }}>{label}</div>
      <div className="t-num" style={{ fontSize: 28, color: colors.fg, marginTop: 2, lineHeight: 1 }}>{value}</div>
    </div>
  );
}

function SectionLabel({ children, tone }) {
  const color = tone === 'present' ? 'var(--present)' : tone === 'absent' ? 'var(--absent)' : 'var(--ink-3)';
  return (
    <div className="t-eyebrow" style={{
      color, marginTop: 12, marginBottom: 4, padding: '6px 4px',
      display: 'flex', alignItems: 'center', gap: 8,
    }}>
      <span style={{ width: 3, height: 12, background: 'currentColor', borderRadius: 2 }}/>
      {children}
    </div>
  );
}

function PersonRow({ letter, name, state }) {
  const isOn = state === 'present';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: '12px 14px',
      borderRadius: 14,
      background: isOn ? 'color-mix(in oklch, var(--present) 6%, var(--card))' : 'var(--card)',
    }}>
      <Avatar letter={letter} tone={isOn ? 'present' : 'absent'}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{name}</div>
        <div style={{ fontSize: 12, color: isOn ? 'var(--present)' : 'var(--ink-3)' }}>{isOn ? 'Marked present' : 'Absent'}</div>
      </div>
      <button className={`toggle ${isOn ? 'is-on' : ''}`}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Mark-everyone — replaces the 3-dot dropdown with an inline action sheet
// ─────────────────────────────────────────────────────────────
function MarkEveryoneSheet({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div style={{ flex: 1, background: 'rgba(0,0,0,0.45)', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
        <div style={{ background: 'var(--card)', borderRadius: '28px 28px 0 0', padding: '20px 22px 32px', position: 'relative' }}>
          <div style={{ width: 38, height: 4, borderRadius: 2, background: 'var(--ink-4)', opacity: 0.4, margin: '0 auto 18px' }}/>
          <div className="t-headline" style={{ fontSize: 24, color: 'var(--ink)' }}>Bulk attendance</div>
          <div className="t-body" style={{ marginTop: 6 }}>Apply a status to all 5 members. You can change any of them after.</div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 18 }}>
            <BulkBtn icon={Ic.check(20)} label="All present" tone="present" hint="5 members"/>
            <BulkBtn icon={Ic.x(20)} label="All absent" tone="absent" hint="5 members"/>
          </div>
          <BulkBtn icon={<Ic.spark/>} label="Smart defaults" tone="neutral" hint="From past 8 sessions · 3 present, 1 absent, 1 unsure" wide/>

          <button className="btn btn-soft" style={{ marginTop: 16, width: '100%' }}>Cancel</button>
        </div>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function BulkBtn({ icon, label, tone, hint, wide }) {
  const colors = {
    present: { bg: 'color-mix(in oklch, var(--present) 10%, transparent)', fg: 'var(--present)', ring: 'var(--present)' },
    absent: { bg: 'color-mix(in oklch, var(--absent) 10%, transparent)', fg: 'var(--absent)', ring: 'var(--absent)' },
    neutral: { bg: 'var(--card-soft)', fg: 'var(--ink)', ring: 'var(--ink-3)' },
  }[tone];
  return (
    <button style={{
      gridColumn: wide ? '1 / -1' : undefined,
      marginTop: wide ? 10 : 0,
      background: colors.bg, color: colors.fg,
      border: 0, cursor: 'pointer',
      padding: '16px 18px',
      borderRadius: 18,
      display: 'flex', alignItems: 'center', gap: 14, textAlign: 'left',
      fontFamily: 'var(--font-sans)',
    }}>
      <div style={{ width: 40, height: 40, borderRadius: 12, background: 'color-mix(in oklch, currentColor 18%, var(--card))', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{icon}</div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 600 }}>{label}</div>
        <div style={{ fontSize: 12, opacity: 0.7, marginTop: 2 }}>{hint}</div>
      </div>
    </button>
  );
}

// ─────────────────────────────────────────────────────────────
// Family management — NEW
// ─────────────────────────────────────────────────────────────
function FamiliesScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div className="t-display" style={{ fontSize: 22, color: 'var(--ink)' }}>Families</div>
        <div style={{ display: 'flex' }}>
          <button className="icon-btn"><Ic.search/></button>
        </div>
      </div>

      <div style={{ padding: '6px 18px', display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 14, padding: '12px 14px' }}>
          <div className="t-eyebrow">Families</div>
          <div className="t-num" style={{ fontSize: 28, color: 'var(--ink)', lineHeight: 1, marginTop: 2 }}>3</div>
        </div>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 14, padding: '12px 14px' }}>
          <div className="t-eyebrow">Members</div>
          <div className="t-num" style={{ fontSize: 28, color: 'var(--ink)', lineHeight: 1, marginTop: 2 }}>17</div>
        </div>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 14, padding: '12px 14px' }}>
          <div className="t-eyebrow">Solo</div>
          <div className="t-num" style={{ fontSize: 28, color: 'var(--ink)', lineHeight: 1, marginTop: 2 }}>2</div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 90px' }}>
        <FamilyCard name="Smith" count={4} members={[
          { letter: 'A', name: 'Alice', role: 'Adult' },
          { letter: 'B', name: 'Bob', role: 'Adult' },
          { letter: 'L', name: 'Liam', role: 'Child · 8' },
          { letter: 'M', name: 'Mia', role: 'Child · 5' },
        ]}/>
        <FamilyCard name="Jones" count={3} members={[
          { letter: 'C', name: 'Carol', role: 'Adult' },
          { letter: 'D', name: 'Devon', role: 'Adult' },
          { letter: 'F', name: 'Fern', role: 'Teen · 14' },
        ]}/>
        <FamilyCard name="Solo · loners" count={2} members={[
          { letter: 'D', name: 'Dan Solo', role: 'Adult' },
          { letter: 'E', name: 'Eve Lonely', role: 'Adult' },
        ]} solo/>
      </div>

      <button className="fab">{Ic.plus(26)}</button>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function FamilyCard({ name, count, members, solo }) {
  return (
    <div className="card" style={{ padding: 18, marginBottom: 14 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
        <div style={{
          width: 48, height: 48, borderRadius: 14,
          background: 'color-mix(in oklch, var(--primary) 14%, transparent)',
          color: 'var(--primary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>{solo ? <Ic.person/> : <Ic.family/>}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="t-headline" style={{ fontSize: 22, color: 'var(--ink)' }}>{name}</div>
          <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{count} {count === 1 ? 'member' : 'members'} · 92% avg attendance</div>
        </div>
        <button className="icon-btn" style={{ width: 32, height: 32 }}><Ic.moreV/></button>
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 14 }}>
        {members.map((m, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '6px 12px 6px 6px',
            background: 'var(--card-soft)',
            borderRadius: 999,
          }}>
            <Avatar letter={m.letter} size={28}/>
            <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--ink)' }}>{m.name}</div>
            <div style={{ fontSize: 11, color: 'var(--ink-3)' }}>· {m.role}</div>
          </div>
        ))}
        <button style={{
          background: 'transparent', border: '1.5px dashed var(--hair)',
          color: 'var(--ink-3)', padding: '6px 12px', borderRadius: 999,
          fontSize: 13, fontWeight: 500, fontFamily: 'var(--font-sans)',
          cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 6,
        }}>{Ic.plus(14)} Add</button>
      </div>
    </div>
  );
}

// Family edit/detail screen
function FamilyEditScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div className="t-eyebrow">Edit family</div>
        <button className="icon-btn"><Ic.trash/></button>
      </div>
      <div style={{ padding: '0 22px 22px', flex: 1, overflowY: 'auto' }}>
        <div className="t-display" style={{ fontSize: 44, color: 'var(--ink)', marginTop: 10 }}>Smith</div>
        <div className="t-body" style={{ marginTop: 6 }}>4 members · joined Apr 2025</div>

        <div style={{ marginTop: 20 }}>
          <div className="t-eyebrow" style={{ marginBottom: 10 }}>Family name</div>
          <input defaultValue="Smith" style={{
            width: '100%', background: 'var(--card-soft)', border: 0, borderRadius: 14,
            padding: '14px 16px', fontSize: 16, fontFamily: 'var(--font-sans)', color: 'var(--ink)',
          }}/>
        </div>

        <div style={{ marginTop: 22, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div className="t-eyebrow">Members</div>
          <button className="btn btn-ghost" style={{ padding: '6px 12px', fontSize: 13 }}>{Ic.plus(14)} Add member</button>
        </div>
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            { l: 'A', n: 'Alice Smith', r: 'Adult · head' },
            { l: 'B', n: 'Bob Smith', r: 'Adult' },
            { l: 'L', n: 'Liam Smith', r: 'Child · 8' },
            { l: 'M', n: 'Mia Smith', r: 'Child · 5' },
          ].map((m, i) => (
            <div key={i} className="card-soft" style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
              <Avatar letter={m.l}/>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{m.n}</div>
                <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>{m.r}</div>
              </div>
              <button className="icon-btn" style={{ width: 32, height: 32 }}><Ic.edit/></button>
            </div>
          ))}
        </div>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Session Summary — redesigned (editorial)
// ─────────────────────────────────────────────────────────────
function SummaryScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div style={{ display: 'flex', gap: 4 }}>
          <button className="icon-btn"><Ic.info/></button>
          <button className="icon-btn"><Ic.upload/></button>
          <button className="icon-btn" style={{ color: 'var(--absent)' }}><Ic.trash/></button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 22px 80px' }}>
        <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>Saved · May 24, 10:42</div>
        <div className="t-display" style={{ fontSize: 38, color: 'var(--ink)', marginTop: 6 }}>Sunday Service</div>

        {/* The hero — large editorial split */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 0, marginTop: 22, position: 'relative' }}>
          <div>
            <div className="t-eyebrow" style={{ color: 'var(--present)' }}>Present</div>
            <div className="t-num" style={{ fontSize: 96, color: 'var(--present)', lineHeight: 0.95, marginTop: 4 }}>3</div>
            <div className="t-body" style={{ marginTop: 4, fontSize: 13 }}>of 5 expected · 60%</div>
          </div>
          <div style={{ paddingLeft: 18, borderLeft: '1px solid var(--hair)' }}>
            <div className="t-eyebrow" style={{ color: 'var(--absent)' }}>Absent</div>
            <div className="t-num" style={{ fontSize: 96, color: 'var(--absent)', lineHeight: 0.95, marginTop: 4 }}>2</div>
            <div className="t-body" style={{ marginTop: 4, fontSize: 13 }}>3 of last 8: ↓ trending</div>
          </div>
        </div>

        {/* Tape rule + secondary stats */}
        <div style={{ marginTop: 20, padding: '14px 16px', background: 'var(--card-soft)', borderRadius: 16, display: 'flex', alignItems: 'center', gap: 16 }}>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow">Consistent · 8 wk</div>
            <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)', marginTop: 2 }} data-comment-anchor="cc-1">
              Alice S., Ben K. <span style={{ color: 'var(--ink-mute)', fontWeight: 400 }}>+2</span>
            </div>
          </div>
          <div style={{ width: 1, height: 28, background: 'var(--hair)' }}/>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow">Missed today</div>
            <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)', marginTop: 2 }}>Carol, Eve</div>
          </div>
        </div>

        {/* The redesigned segmented control — replaces 2 separate chip toggles */}
        <div style={{ marginTop: 22, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div className="t-eyebrow">Roster</div>
          <div className="seg">
            <button className="is-on"><Ic.family/> Family</button>
            <button><Ic.checks/> Status</button>
          </div>
        </div>

        <div style={{ marginTop: 10 }}>
          <SectionLabel>Smith Family · 2 of 2</SectionLabel>
          <SummaryRow letter="A" name="Alice Smith" state="present"/>
          <SummaryRow letter="B" name="Bob Smith" state="present"/>
          <SectionLabel>Jones Family · 0 of 1</SectionLabel>
          <SummaryRow letter="C" name="Carol Jones" state="absent"/>
          <SectionLabel>Loners · 1 of 2</SectionLabel>
          <SummaryRow letter="D" name="Dan Solo" state="present"/>
          <SummaryRow letter="E" name="Eve Lonely" state="absent"/>
        </div>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function SummaryRow({ letter, name, state }) {
  const isOn = state === 'present';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: '12px 0',
      borderBottom: '1px solid var(--hair)',
    }}>
      <Avatar letter={letter} tone={isOn ? 'present' : 'absent'}/>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{name}</div>
      </div>
      {isOn ? (
        <div style={{ color: 'var(--present)', display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 500 }}>
          {Ic.check(14)} Present
        </div>
      ) : (
        <div style={{ color: 'var(--absent)', display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, fontWeight: 500 }}>
          {Ic.x(14)} Absent
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Onboarding (4 cards) — Editorial postcards
// ─────────────────────────────────────────────────────────────
function OnboardingScreen({ step = 1, theme = 'light' }) {
  const slides = [
    {
      eyebrow: '01 · Quick marking',
      title: 'Swipe with one thumb.',
      body: 'Right for present, left for absent. The deck handles the rest.',
      art: 'deck',
    },
    {
      eyebrow: '02 · Session history',
      title: 'Every Sunday, remembered.',
      body: 'Review past sessions and watch trends settle in.',
      art: 'history',
    },
    {
      eyebrow: '03 · Members & families',
      title: 'Roll up by family.',
      body: 'Group members into families. Smart defaults speed up the rest.',
      art: 'family',
    },
    {
      eyebrow: '04 · Yours, fully.',
      title: 'Local-first. Encrypted backup.',
      body: 'Your data stays on your device. Sync to your own Google Drive — never ours.',
      art: 'cloud',
    },
  ];
  const s = slides[step - 1];
  const isLast = step === slides.length;
  return (
    <div className="screen">
      <StatusBar/>
      <div style={{ padding: '14px 22px 0', display: 'flex', alignItems: 'center', gap: 8 }}>
        {slides.map((_, i) => (
          <div key={i} style={{
            height: 4, borderRadius: 2,
            width: i + 1 === step ? 28 : 14,
            background: i + 1 === step ? 'var(--primary)' : 'var(--bg-3)',
            transition: 'all .25s',
          }}/>
        ))}
        <button className="btn btn-ghost" style={{ padding: '6px 12px', marginLeft: 'auto', fontSize: 14 }}>
          {isLast ? 'Get started →' : 'Skip'}
        </button>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '0 28px' }}>
        {/* Art area — bleeds to right edge */}
        <div style={{ flex: 1, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 280, marginTop: 20 }}>
          {s.art === 'deck' && <OnboardingDeckArt/>}
          {s.art === 'history' && <OnboardingHistoryArt/>}
          {s.art === 'family' && <OnboardingFamilyArt/>}
          {s.art === 'cloud' && <OnboardingCloudArt/>}
        </div>

        <div style={{ paddingBottom: 32 }}>
          <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>{s.eyebrow}</div>
          <div className="t-display" style={{ fontSize: 36, color: 'var(--ink)', marginTop: 8, textWrap: 'pretty' }}>{s.title}</div>
          <div className="t-body" style={{ marginTop: 12, fontSize: 16, maxWidth: 320 }}>{s.body}</div>
        </div>
      </div>

      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function OnboardingDeckArt() {
  return (
    <div style={{ position: 'relative', width: 280, height: 280 }}>
      <div className="card" style={{ position: 'absolute', top: 30, left: 10, width: 170, height: 220, transform: 'rotate(-8deg)', padding: 18, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10 }}>
        <Avatar letter="J" size={64} tone="absent"/>
        <div className="t-headline" style={{ fontSize: 18 }}>Jane Smith</div>
      </div>
      <div className="card" style={{ position: 'absolute', top: 0, left: 70, width: 200, height: 260, transform: 'rotate(4deg)', padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12 }}>
        <Avatar letter="J" size={80} tone="present"/>
        <div className="t-headline" style={{ fontSize: 22, color: 'var(--ink)' }}>John Doe</div>
      </div>
      <div className="stamp stamp-present" style={{ position: 'absolute', top: 15, right: -10 }}>Present</div>
      <div className="stamp stamp-absent" style={{ position: 'absolute', bottom: 80, left: -30 }}>Absent</div>
    </div>
  );
}

function OnboardingHistoryArt() {
  const sessions = [
    { date: 'Mar 29', dow: 'Sunday · 10:00 AM', p: 42, a: 3 },
    { date: 'Mar 25', dow: 'Wednesday · 7:00 PM', p: 28, a: 14 },
    { date: 'Mar 20', dow: 'Friday · 6:30 PM', p: 35, a: 5 },
  ];
  return (
    <div style={{ width: 290, display: 'flex', flexDirection: 'column', gap: 10 }}>
      {sessions.map((s, i) => (
        <div key={i} className="card" style={{ padding: '14px 16px', transform: `translateX(${i * 6}px)` }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <div>
              <div className="t-headline" style={{ fontSize: 18, color: 'var(--ink)' }}>{s.date}</div>
              <div style={{ fontSize: 11, color: 'var(--ink-3)' }}>{s.dow}</div>
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
              <span className="t-num" style={{ color: 'var(--present)', fontSize: 20 }}>{s.p}</span>
              <span style={{ color: 'var(--ink-4)' }}>·</span>
              <span className="t-num" style={{ color: 'var(--absent)', fontSize: 20 }}>{s.a}</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

function OnboardingFamilyArt() {
  return (
    <div style={{ width: 290 }}>
      <div className="card" style={{ padding: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: 'color-mix(in oklch, var(--primary) 14%, transparent)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic.family/></div>
          <div>
            <div className="t-headline" style={{ fontSize: 19 }}>Smith</div>
            <div style={{ fontSize: 11, color: 'var(--ink-3)' }}>4 members</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 12, flexWrap: 'wrap' }}>
          {['Alice', 'Bob', 'Liam', 'Mia'].map((n, i) => (
            <div key={i} style={{ background: 'var(--card-soft)', padding: '4px 10px 4px 4px', borderRadius: 999, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Avatar letter={n[0]} size={22}/>
              <span style={{ fontSize: 12, fontWeight: 500 }}>{n}</span>
            </div>
          ))}
        </div>
      </div>
      <div className="card-soft" style={{ marginTop: 12, padding: 14, transform: 'translateX(14px)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Avatar letter="D" size={36}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>Dan Solo</div>
            <div style={{ fontSize: 11, color: 'var(--ink-3)' }}>Loner</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function OnboardingCloudArt() {
  return (
    <div style={{ width: 280, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
      <div style={{
        width: 110, height: 110, borderRadius: 32,
        background: 'color-mix(in oklch, var(--primary) 10%, transparent)',
        color: 'var(--primary)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
      }}>
        <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/></svg>
        <svg style={{ position: 'absolute', top: -16, right: -16 }} width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M12 2v6m-3-3l3-3 3 3M4 14h16M6 18h12M8 22h8"/></svg>
      </div>
      <div className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, width: '100%' }}>
        <div style={{ width: 8, height: 8, borderRadius: 4, background: 'oklch(70% 0.18 145)' }}/>
        <div style={{ flex: 1, fontSize: 13, fontWeight: 500 }}>Last synced 2 min ago</div>
        <span className="t-eyebrow" style={{ color: 'var(--ink-3)' }}>3.0 KB</span>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Add Event — redesigned with editorial sliders/chips
// ─────────────────────────────────────────────────────────────
function AddEventScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.close/></button>
        <div className="t-eyebrow">New event</div>
        <div style={{ width: 40 }}/>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 22px 110px' }}>
        <div className="t-display" style={{ fontSize: 36, color: 'var(--ink)' }}>What are we<br/>tracking?</div>

        <div style={{ marginTop: 26 }}>
          <div className="t-eyebrow" style={{ marginBottom: 8 }}>Name</div>
          <input defaultValue="Lord's Table" style={{
            width: '100%', background: 'var(--card-soft)', border: 0, borderRadius: 14,
            padding: '14px 16px', fontSize: 18, fontFamily: 'var(--font-display)', color: 'var(--ink)',
            fontVariationSettings: "'opsz' 72",
          }}/>
        </div>

        <div style={{ marginTop: 18, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <div>
            <div className="t-eyebrow" style={{ marginBottom: 8 }}>Time</div>
            <div className="card-soft" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
              <Ic.clock/>
              <span className="t-num" style={{ fontSize: 18, color: 'var(--ink)' }}>10:00</span>
            </div>
          </div>
          <div>
            <div className="t-eyebrow" style={{ marginBottom: 8 }}>Frequency</div>
            <div className="card-soft" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center' }}>
              <span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>Weekly</span>
              <Ic.chevD/>
            </div>
          </div>
        </div>

        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow" style={{ marginBottom: 10 }}>Repeats on</div>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'space-between' }}>
            {['S','M','T','W','T','F','S'].map((d, i) => {
              const active = i === 0 || i === 3;
              return (
                <button key={i} style={{
                  width: 40, height: 40, borderRadius: '50%',
                  border: 0, cursor: 'pointer',
                  background: active ? 'var(--primary)' : 'var(--card-soft)',
                  color: active ? 'var(--on-primary)' : 'var(--ink-3)',
                  fontSize: 13, fontWeight: 600, fontFamily: 'var(--font-sans)',
                }}>{d}</button>
              );
            })}
          </div>
        </div>

        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow" style={{ marginBottom: 10 }}>Roster</div>
          <div className="card-soft" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
            <Ic.people/>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>All members</div>
              <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>5 people · change later</div>
            </div>
            <Ic.chevR/>
          </div>
        </div>
      </div>

      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 22, padding: '0 22px' }}>
        <button className="btn btn-primary" style={{ width: '100%', padding: '18px' }}>Create event</button>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Settings — refresh
// ─────────────────────────────────────────────────────────────
function SettingsScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div className="t-eyebrow">Settings</div>
        <div style={{ width: 40 }}/>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 22px 80px' }}>
        <div className="t-display" style={{ fontSize: 32, color: 'var(--ink)' }}>Settings</div>

        <SettingSection title="Appearance">
          <SettingRow icon={<Ic.palette/>} title="Theme" value="System"/>
          <SettingRow icon={<Ic.lock/>} title="App lock" value="Off" toggle/>
        </SettingSection>

        <SettingSection title="Sync · Google">
          <div className="card" style={{ padding: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 14, background: 'color-mix(in oklch, var(--primary) 14%, transparent)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic.cloud/></div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 500 }}>Google Drive</div>
                <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>user@example.com · 2 min ago</div>
              </div>
              <div style={{ width: 8, height: 8, borderRadius: 4, background: 'oklch(70% 0.18 145)' }}/>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
              <button className="btn btn-soft" style={{ flex: 1, padding: '10px', color: 'var(--absent)' }}><Ic.signOut/> Sign out</button>
              <button className="btn btn-primary" style={{ flex: 1, padding: '10px' }}><Ic.sync/> Sync</button>
            </div>
          </div>
        </SettingSection>

        <SettingSection title="Data">
          <SettingRow icon={<Ic.people/>} title="Manage members" sub="17 members across 3 families"/>
          <SettingRow icon={<Ic.family/>} title="Manage families" sub="Edit, merge, split"/>
          <SettingRow icon={<Ic.save/>} title="Backup to device" sub="Last: May 25 · 3.0 KB"/>
          <SettingRow icon={<Ic.doc/>} title="Advanced reports" sub="Filter & export CSV"/>
        </SettingSection>

        <SettingSection title="About">
          <SettingRow icon={<Ic.bug/>} title="Send feedback"/>
          <SettingRow icon={<Ic.shield/>} title="Privacy policy"/>
        </SettingSection>

        <div className="t-eyebrow" style={{ textAlign: 'center', marginTop: 28, color: 'var(--ink-4)' }}>Attendance · v1.3.0</div>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function SettingSection({ title, children }) {
  return (
    <div style={{ marginTop: 22 }}>
      <div className="t-eyebrow" style={{ marginBottom: 10 }}>{title}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>{children}</div>
    </div>
  );
}

function SettingRow({ icon, title, sub, value, toggle }) {
  return (
    <div className="card-soft" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
      <div style={{ color: 'var(--primary)' }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{title}</div>
        {sub && <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{sub}</div>}
      </div>
      {toggle ? <div className="toggle"/> : value ? <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--ink-3)' }}>{value}</div> : <Ic.chevR/>}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Members management
// ─────────────────────────────────────────────────────────────
function MembersScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div className="t-eyebrow">Members</div>
        <button className="icon-btn"><Ic.info/></button>
      </div>

      <div style={{ padding: '4px 22px 0' }}>
        <div className="t-display" style={{ fontSize: 32 }}>17 people<br/><span style={{ color: 'var(--ink-3)' }}>3 families</span></div>

        <div style={{ marginTop: 18, background: 'var(--card-soft)', borderRadius: 14, padding: '4px 4px 4px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <Ic.search/>
          <input placeholder="Find or add member" style={{ flex: 1, background: 'transparent', border: 0, padding: '12px 0', fontSize: 14, fontFamily: 'var(--font-sans)', color: 'var(--ink)' }}/>
          <button className="btn btn-primary" style={{ padding: '10px 14px', borderRadius: 12 }}>{Ic.plus(18)}</button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 22px 80px' }}>
        <SectionLabel>Smith Family · 4</SectionLabel>
        {[
          { l: 'A', n: 'Alice Smith', r: 'Adult · head' },
          { l: 'B', n: 'Bob Smith', r: 'Adult' },
          { l: 'L', n: 'Liam Smith', r: 'Child · 8' },
          { l: 'M', n: 'Mia Smith', r: 'Child · 5' },
        ].map((m, i) => <MemberRow key={i} {...m}/>)}
        <SectionLabel>Jones Family · 1</SectionLabel>
        <MemberRow l="C" n="Carol Jones" r="Adult"/>
        <SectionLabel>Loners · 2</SectionLabel>
        <MemberRow l="D" n="Dan Solo" r="Adult"/>
        <MemberRow l="E" n="Eve Lonely" r="Adult"/>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function MemberRow({ l, n, r }) {
  return (
    <div style={{ padding: '12px 4px', display: 'flex', alignItems: 'center', gap: 14 }}>
      <Avatar letter={l}/>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{n}</div>
        <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>{r}</div>
      </div>
      <button className="icon-btn" style={{ width: 32, height: 32 }}><Ic.edit/></button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Suggest Families — NEW
// Bulk-group the unassigned roster by shared last name.
// Each cluster is editable: rename, drop a wrong match, skip,
// or confirm. Sticky bottom CTA creates them all at once.
// ─────────────────────────────────────────────────────────────
function SuggestFamiliesScreen({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div className="t-eyebrow">Step 4 of 4</div>
        <button className="icon-btn"><Ic.moreV/></button>
      </div>

      <div style={{ padding: '6px 22px 0' }}>
        <div className="t-eyebrow" style={{ color: 'var(--primary)' }}>Group by last name</div>
        <div className="t-display" style={{ fontSize: 34, color: 'var(--ink)', marginTop: 6, lineHeight: 1 }}>
          We spotted <span style={{ color: 'var(--primary)' }}>4 families</span> in your roster.
        </div>
        <div className="t-body" style={{ fontSize: 14, marginTop: 10, color: 'var(--ink-2)', maxWidth: 320 }}>
          Tap a member to remove them from a group. Rename or skip any cluster — nothing is created until you tap <em>Create</em>.
        </div>

        {/* meter strip */}
        <div style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1, height: 6, borderRadius: 999, background: 'var(--card-soft)', overflow: 'hidden', display: 'flex' }}>
            <div style={{ width: '78%', background: 'var(--primary)' }}/>
            <div style={{ width: '22%', background: 'var(--hair)' }}/>
          </div>
          <div style={{ fontSize: 11, color: 'var(--ink-3)', fontFamily: 'var(--font-sans)', letterSpacing: '.04em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>11 / 14 grouped</div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '18px 18px 110px' }}>
        <SuggestCard
          name="Smith"
          confidence="high"
          members={[
            { l: 'A', n: 'Alice Smith' },
            { l: 'B', n: 'Bob Smith' },
            { l: 'L', n: 'Liam Smith' },
            { l: 'M', n: 'Mia Smith' },
          ]}
        />
        <SuggestCard
          name="Jones"
          confidence="high"
          members={[
            { l: 'C', n: 'Carol Jones' },
            { l: 'D', n: 'Devon Jones' },
            { l: 'F', n: 'Fern Jones' },
          ]}
        />
        <SuggestCard
          name="Patel"
          confidence="med"
          note="Different first-name pattern — review"
          members={[
            { l: 'R', n: 'Ravi Patel' },
            { l: 'P', n: 'Priya Patel' },
            { l: 'K', n: 'Kiran Patel', muted: true },
          ]}
        />
        <SuggestCard
          name="O'Brien"
          confidence="low"
          note="Only 2 — could be coincidence"
          members={[
            { l: 'M', n: "Maeve O'Brien" },
            { l: 'S', n: "Sean O'Brien" },
          ]}
        />

        <div style={{
          marginTop: 10, padding: '14px 16px',
          borderRadius: 14, border: '1.5px dashed var(--hair)',
          display: 'flex', alignItems: 'center', gap: 12,
          color: 'var(--ink-3)',
        }}>
          <div style={{ width: 32, height: 32, borderRadius: 10, background: 'var(--card-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ic.person/></div>
          <div style={{ flex: 1, fontSize: 13 }}>
            <div style={{ color: 'var(--ink-2)', fontWeight: 500 }}>3 stay solo</div>
            <div style={{ marginTop: 2 }}>Dan Solo · Eve Lonely · Sam Quinn</div>
          </div>
        </div>
      </div>

      {/* sticky CTA */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        padding: '14px 18px 22px',
        background: 'linear-gradient(to top, var(--bg) 60%, transparent)',
        display: 'flex', gap: 10, alignItems: 'center',
      }}>
        <button style={{
          flex: '0 0 auto', background: 'transparent', border: 0,
          color: 'var(--ink-3)', fontSize: 13, fontWeight: 500,
          fontFamily: 'var(--font-sans)', padding: '14px 6px',
        }}>Skip all</button>
        <button className="btn btn-primary" style={{ flex: 1, padding: '16px 20px', fontSize: 15 }}>
          Create 4 families
        </button>
      </div>
    </div>
  );
}

function SuggestCard({ name, members, confidence = 'high', note }) {
  const tone = confidence === 'high'
    ? { dot: 'var(--present)', label: 'High match' }
    : confidence === 'med'
    ? { dot: 'var(--clay-deep)', label: 'Review' }
    : { dot: 'var(--ink-3)', label: 'Low confidence' };
  return (
    <div className="card" style={{ padding: 16, marginBottom: 12 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{
          width: 44, height: 44, borderRadius: 12,
          background: 'color-mix(in oklch, var(--primary) 12%, transparent)',
          color: 'var(--primary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flex: '0 0 auto',
        }}><Ic.family/></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
            <div className="t-headline" style={{ fontSize: 20, color: 'var(--ink)' }}>{name} Family</div>
            <div style={{ fontSize: 12, color: 'var(--ink-3)' }}>· {members.filter(m => !m.muted).length} members</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: tone.dot }}/>
            <div className="t-eyebrow" style={{ color: 'var(--ink-3)' }}>{tone.label}{note ? ` · ${note}` : ''}</div>
          </div>
        </div>
        <button className="icon-btn" style={{ width: 32, height: 32 }}><Ic.edit/></button>
      </div>

      {/* member chips */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 14 }}>
        {members.map((m, i) => (
          <div key={i} style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '6px 10px 6px 6px',
            borderRadius: 999,
            background: m.muted ? 'transparent' : 'var(--card-soft)',
            border: m.muted ? '1.5px dashed var(--hair)' : 'none',
            opacity: m.muted ? 0.6 : 1,
            fontFamily: 'var(--font-sans)',
          }}>
            <div style={{
              width: 22, height: 22, borderRadius: 999,
              background: 'color-mix(in oklch, var(--primary) 16%, transparent)',
              color: 'var(--primary)',
              fontSize: 11, fontWeight: 600,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              textDecoration: m.muted ? 'line-through' : 'none',
            }}>{m.l}</div>
            <span style={{ fontSize: 13, color: m.muted ? 'var(--ink-3)' : 'var(--ink-2)', fontWeight: 500, textDecoration: m.muted ? 'line-through' : 'none' }}>{m.n}</span>
            <button style={{
              width: 18, height: 18, borderRadius: 999, border: 0,
              background: 'transparent', color: 'var(--ink-3)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', padding: 0,
            }}>{Ic.x(12)}</button>
          </div>
        ))}
      </div>

      {/* footer actions */}
      <div style={{ marginTop: 12, paddingTop: 12, borderTop: '1px solid var(--hair)', display: 'flex', alignItems: 'center', gap: 6 }}>
        <button style={{
          background: 'transparent', border: 0,
          color: 'var(--ink-3)', fontSize: 12, fontWeight: 500,
          fontFamily: 'var(--font-sans)', padding: '4px 8px',
          cursor: 'pointer',
        }}>Skip</button>
        <div style={{ flex: 1 }}/>
        <button style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          background: 'transparent', border: '1.5px solid var(--hair)',
          color: 'var(--ink-2)', padding: '6px 12px', borderRadius: 999,
          fontSize: 12, fontWeight: 500, fontFamily: 'var(--font-sans)',
          cursor: 'pointer',
        }}>{Ic.plus(12)} Add member</button>
        <button style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          background: 'var(--primary)', border: 0,
          color: 'var(--on-primary)', padding: '7px 14px', borderRadius: 999,
          fontSize: 12, fontWeight: 600, fontFamily: 'var(--font-sans)',
          cursor: 'pointer',
        }}>{Ic.check(12)} Confirm</button>
      </div>
    </div>
  );
}

// Variation: the same screen as a sheet/banner state on Families index
function FamiliesWithSuggestionBanner({ theme = 'light' }) {
  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header">
        <button className="icon-btn"><Ic.back/></button>
        <div className="t-display" style={{ fontSize: 22, color: 'var(--ink)' }}>Families</div>
        <div style={{ display: 'flex' }}>
          <button className="icon-btn"><Ic.search/></button>
        </div>
      </div>

      {/* The suggestion banner — the discovery moment */}
      <div style={{ padding: '6px 18px 0' }}>
        <div style={{
          position: 'relative', overflow: 'hidden',
          background: 'color-mix(in oklch, var(--primary) 10%, var(--bg))',
          borderRadius: 18, padding: 16,
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{
            width: 44, height: 44, borderRadius: 12,
            background: 'var(--primary)', color: 'var(--on-primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flex: '0 0 auto',
          }}><Ic.family/></div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--ink)', fontFamily: 'var(--font-sans)' }}>
              4 possible families spotted
            </div>
            <div style={{ fontSize: 12, color: 'var(--ink-2)', marginTop: 2, fontFamily: 'var(--font-sans)' }}>
              From shared last names · 11 of 14 members
            </div>
          </div>
          <button style={{
            background: 'var(--ink)', color: 'var(--bg)',
            border: 0, borderRadius: 999, padding: '8px 14px',
            fontSize: 12, fontWeight: 600, fontFamily: 'var(--font-sans)',
            cursor: 'pointer', flex: '0 0 auto',
          }}>Review</button>
        </div>
      </div>

      <div style={{ padding: '14px 18px 0', display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 14, padding: '10px 12px' }}>
          <div className="t-eyebrow">Families</div>
          <div className="t-num" style={{ fontSize: 24, color: 'var(--ink)', lineHeight: 1, marginTop: 2 }}>0</div>
        </div>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 14, padding: '10px 12px' }}>
          <div className="t-eyebrow">Members</div>
          <div className="t-num" style={{ fontSize: 24, color: 'var(--ink)', lineHeight: 1, marginTop: 2 }}>14</div>
        </div>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 14, padding: '10px 12px' }}>
          <div className="t-eyebrow">Ungrouped</div>
          <div className="t-num" style={{ fontSize: 24, color: 'var(--clay-deep)', lineHeight: 1, marginTop: 2 }}>14</div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 90px' }}>
        <div className="t-eyebrow" style={{ marginBottom: 8 }}>Ungrouped members</div>
        {[
          { l: 'A', n: 'Alice Smith' },
          { l: 'B', n: 'Bob Smith' },
          { l: 'C', n: 'Carol Jones' },
          { l: 'D', n: 'Devon Jones' },
          { l: 'F', n: 'Fern Jones' },
          { l: 'L', n: 'Liam Smith' },
          { l: 'M', n: 'Mia Smith' },
        ].map((m, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '10px 4px', borderBottom: '1px solid var(--hair)',
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 999,
              background: 'var(--card-soft)', color: 'var(--ink-2)',
              fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 600,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>{m.l}</div>
            <div style={{ flex: 1, fontSize: 15, color: 'var(--ink)', fontFamily: 'var(--font-sans)' }}>{m.n}</div>
            <button style={{
              background: 'transparent', border: '1.5px dashed var(--hair)',
              color: 'var(--ink-3)', padding: '6px 12px', borderRadius: 999,
              fontSize: 12, fontWeight: 500, fontFamily: 'var(--font-sans)',
              cursor: 'pointer',
            }}>Assign</button>
          </div>
        ))}
      </div>

      <button className="fab">{Ic.plus(26)}</button>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

Object.assign(window, {
  HubScreen, HubEmpty, ListScreen, MarkEveryoneSheet,
  FamiliesScreen, FamilyEditScreen, SummaryScreen,
  OnboardingScreen, AddEventScreen, SettingsScreen, MembersScreen,
  SuggestFamiliesScreen, FamiliesWithSuggestionBanner,
});
