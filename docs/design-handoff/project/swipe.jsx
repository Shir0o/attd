// Convocation — swipe deck (the centerpiece). Three variations.

const { Ic, Phone, StatusBar, NavPill, Avatar } = window;

const SAMPLE_PEOPLE = [
  { id: 1, first: 'Alice', last: 'Smith', family: 'Smith', initials: 'AS' },
  { id: 2, first: 'Bob', last: 'Smith', family: 'Smith', initials: 'BS' },
  { id: 3, first: 'Carol', last: 'Jones', family: 'Jones', initials: 'CJ' },
  { id: 4, first: 'Dan', last: 'Solo', family: '—', initials: 'DS' },
  { id: 5, first: 'Eve', last: 'Lonely', family: '—', initials: 'EL' },
  { id: 6, first: 'Mia', last: 'Smith', family: 'Smith', initials: 'MS' },
  { id: 7, first: 'Liam', last: 'Smith', family: 'Smith', initials: 'LS' },
];

// ─────────────────────────────────────────────────────────────
// Hook — drag gesture with rotation, returns ref + position
// ─────────────────────────────────────────────────────────────
function useDragCard(onCommit) {
  const [dx, setDx] = React.useState(0);
  const [dy, setDy] = React.useState(0);
  const [committing, setCommitting] = React.useState(null); // 'left' | 'right' | null
  const start = React.useRef(null);

  const onPointerDown = (e) => {
    if (committing) return;
    e.currentTarget.setPointerCapture?.(e.pointerId);
    start.current = { x: e.clientX, y: e.clientY };
  };
  const onPointerMove = (e) => {
    if (!start.current) return;
    setDx(e.clientX - start.current.x);
    setDy(e.clientY - start.current.y);
  };
  const onPointerUp = () => {
    if (!start.current) return;
    start.current = null;
    const threshold = 90;
    if (dx > threshold) commit('right');
    else if (dx < -threshold) commit('left');
    else { setDx(0); setDy(0); }
  };
  const commit = (dir) => {
    setCommitting(dir);
    setDx(dir === 'right' ? 500 : -500);
    setDy(80);
    setTimeout(() => {
      onCommit?.(dir);
      setDx(0); setDy(0); setCommitting(null);
    }, 260);
  };
  const rot = Math.max(-18, Math.min(18, dx / 12));
  const stampPresent = Math.max(0, Math.min(1, dx / 80));
  const stampAbsent = Math.max(0, Math.min(1, -dx / 80));
  return { dx, dy, rot, stampPresent, stampAbsent, committing, commit, onPointerDown, onPointerMove, onPointerUp };
}

// ─────────────────────────────────────────────────────────────
// Variation A — Refined card stack (closest to current)
// ─────────────────────────────────────────────────────────────
function SwipeDeckA({ theme = 'light', startIdx = 0 }) {
  const [idx, setIdx] = React.useState(startIdx);
  const [history, setHistory] = React.useState([]); // [{id, result}]
  const present = history.filter(h => h.result === 'present').length;
  const absent = history.filter(h => h.result === 'absent').length;
  const remaining = SAMPLE_PEOPLE.length - history.length;
  const onCommit = (dir) => {
    setHistory(h => [...h, { id: SAMPLE_PEOPLE[idx].id, result: dir === 'right' ? 'present' : 'absent' }]);
    setIdx(i => Math.min(i + 1, SAMPLE_PEOPLE.length - 1));
  };
  const drag = useDragCard(onCommit);
  const cur = SAMPLE_PEOPLE[idx];
  const next = SAMPLE_PEOPLE[idx + 1];

  return (
    <div className="screen">
      <StatusBar/>

      {/* Top bar — eyebrow + close + done */}
      <div className="app-header" style={{ padding: '10px 18px 8px' }}>
        <button className="icon-btn"><Ic.close/></button>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div className="t-eyebrow">Sunday Service · 10:00</div>
          <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>
            <span style={{ color: 'var(--present)', fontWeight: 600 }}>{present}</span> · <span style={{ color: 'var(--absent)', fontWeight: 600 }}>{absent}</span> · <span style={{ fontWeight: 500 }}>{remaining} left</span>
          </div>
        </div>
        <button className="btn btn-ghost" style={{ padding: '8px 14px' }}>Done</button>
      </div>

      {/* Mode segmented control — Deck/List, clean */}
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 12px' }}>
        <div className="seg">
          <button className="is-on"><Ic.deck/> Deck</button>
          <button><Ic.list/> List</button>
        </div>
      </div>

      {/* Progress bar */}
      <div style={{ padding: '0 22px 8px' }}>
        <div style={{ height: 4, background: 'var(--bg-2)', borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${(history.length / SAMPLE_PEOPLE.length) * 100}%`, background: 'var(--primary)', borderRadius: 2, transition: 'width .3s' }}/>
        </div>
      </div>

      {/* Deck area */}
      <div style={{ flex: 1, position: 'relative', padding: '12px 24px 0' }}>
        {/* Hint zones */}
        <div style={{ position: 'absolute', top: 50, left: 8, opacity: drag.stampAbsent * 0.4 + 0.05, transition: 'opacity .15s', color: 'var(--absent)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          {Ic.x(20)}
          <div className="t-eyebrow" style={{ color: 'var(--absent)', fontSize: 9 }}>Absent</div>
        </div>
        <div style={{ position: 'absolute', top: 50, right: 8, opacity: drag.stampPresent * 0.4 + 0.05, transition: 'opacity .15s', color: 'var(--present)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          {Ic.check(20)}
          <div className="t-eyebrow" style={{ color: 'var(--present)', fontSize: 9 }}>Present</div>
        </div>

        {/* Stack — next behind */}
        {next && (
          <div className="card" style={{
            position: 'absolute', top: 24, left: 36, right: 36, bottom: 36,
            transform: 'scale(.94) translateY(8px)',
            opacity: 0.65,
            pointerEvents: 'none',
          }}>
            <CardContent person={next} small/>
          </div>
        )}

        {/* Current */}
        {cur && remaining > 0 && (
          <div
            className="card"
            onPointerDown={drag.onPointerDown}
            onPointerMove={drag.onPointerMove}
            onPointerUp={drag.onPointerUp}
            onPointerCancel={drag.onPointerUp}
            style={{
              position: 'absolute', top: 12, left: 24, right: 24, bottom: 24,
              transform: `translate(${drag.dx}px, ${drag.dy}px) rotate(${drag.rot}deg)`,
              transition: drag.committing ? 'transform .26s cubic-bezier(.5,0,.6,1)' : drag.dx === 0 ? 'transform .25s cubic-bezier(.2,.7,.3,1)' : 'none',
              touchAction: 'none',
              cursor: drag.dx !== 0 ? 'grabbing' : 'grab',
            }}>
            <CardContent person={cur}/>

            {/* Stamps overlay */}
            <div className="stamp stamp-present" style={{ position: 'absolute', top: 28, right: 28, opacity: drag.stampPresent }}>Present</div>
            <div className="stamp stamp-absent" style={{ position: 'absolute', top: 28, left: 28, opacity: drag.stampAbsent }}>Absent</div>
          </div>
        )}

        {/* Done state */}
        {remaining === 0 && (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 32px' }}>
            <div className="t-display" style={{ fontSize: 40, color: 'var(--ink)' }}>All marked.</div>
            <div className="t-body" style={{ marginTop: 12 }}>{present} present, {absent} absent. Tap Done to save.</div>
          </div>
        )}
      </div>

      {/* Action row */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 28, padding: '14px 0 30px' }}>
        <button onClick={() => { setHistory(h => h.slice(0, -1)); setIdx(i => Math.max(i - 1, 0)); }} style={actionBtn('soft')}><Ic.undo/></button>
        <button onClick={() => drag.commit('left')} style={actionBtn('absent')} aria-label="Absent">{Ic.x(28)}</button>
        <button onClick={() => drag.commit('right')} style={actionBtn('present')} aria-label="Present">{Ic.check(28)}</button>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function actionBtn(kind) {
  if (kind === 'present') return { width: 72, height: 72, borderRadius: '50%', border: 0, cursor: 'pointer', background: 'var(--present)', color: 'var(--on-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 12px 30px -10px color-mix(in oklch, var(--present) 60%, transparent)' };
  if (kind === 'absent') return { width: 60, height: 60, borderRadius: '50%', border: '2px solid var(--absent)', cursor: 'pointer', background: 'transparent', color: 'var(--absent)', display: 'flex', alignItems: 'center', justifyContent: 'center' };
  return { width: 52, height: 52, borderRadius: '50%', border: 0, cursor: 'pointer', background: 'var(--card-soft)', color: 'var(--ink-2)', display: 'flex', alignItems: 'center', justifyContent: 'center' };
}

function CardContent({ person, small }) {
  return (
    <div style={{ padding: small ? '32px 22px' : '40px 24px', height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
      <Avatar letter={person.first[0]} size={small ? 70 : 100}/>
      <div style={{ textAlign: 'center' }}>
        <div className="t-display" style={{ fontSize: small ? 28 : 36, color: 'var(--ink)', lineHeight: 1.05 }}>{person.first} {person.last}</div>
        <div className="t-eyebrow" style={{ marginTop: 8 }}>{person.family === '—' ? 'Loner' : `${person.family} family`}</div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Variation B — editorial postcard (signature feel)
// ─────────────────────────────────────────────────────────────
function SwipeDeckB({ theme = 'light' }) {
  const [idx, setIdx] = React.useState(0);
  const [history, setHistory] = React.useState([]);
  const onCommit = (dir) => {
    setHistory(h => [...h, { id: SAMPLE_PEOPLE[idx].id, result: dir === 'right' ? 'present' : 'absent' }]);
    setIdx(i => Math.min(i + 1, SAMPLE_PEOPLE.length - 1));
  };
  const drag = useDragCard(onCommit);
  const cur = SAMPLE_PEOPLE[idx];
  const next = SAMPLE_PEOPLE[idx + 1];
  const remaining = SAMPLE_PEOPLE.length - history.length;
  const present = history.filter(h => h.result === 'present').length;
  const absent = history.filter(h => h.result === 'absent').length;

  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header" style={{ padding: '10px 18px 6px' }}>
        <button className="icon-btn"><Ic.close/></button>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div className="t-eyebrow">Sunday Service</div>
        </div>
        <button className="btn btn-ghost" style={{ padding: '8px 14px' }}>Done</button>
      </div>

      {/* Editorial count rule */}
      <div style={{ padding: '0 24px', display: 'flex', alignItems: 'baseline', gap: 14 }}>
        <div>
          <div className="t-eyebrow" style={{ color: 'var(--present)' }}>Present</div>
          <div className="t-num" style={{ fontSize: 38, color: 'var(--present)', lineHeight: 1 }}>{String(present).padStart(2, '0')}</div>
        </div>
        <div style={{ flex: 1, height: 1, background: 'var(--hair)' }}/>
        <div style={{ textAlign: 'right' }}>
          <div className="t-eyebrow" style={{ color: 'var(--absent)' }}>Absent</div>
          <div className="t-num" style={{ fontSize: 38, color: 'var(--absent)', lineHeight: 1 }}>{String(absent).padStart(2, '0')}</div>
        </div>
      </div>

      <div style={{ padding: '4px 24px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div className="t-eyebrow">Card {Math.min(idx + 1, SAMPLE_PEOPLE.length)} of {SAMPLE_PEOPLE.length}</div>
        <div className="seg" style={{ padding: 3 }}>
          <button className="is-on"><Ic.deck/></button>
          <button><Ic.list/></button>
        </div>
      </div>

      <div style={{ flex: 1, position: 'relative', padding: '14px 26px' }}>
        {/* Underneath card */}
        {next && (
          <PostcardCard person={next} style={{ position: 'absolute', top: 22, left: 50, right: 50, bottom: 60, opacity: 0.5, transform: 'translateY(8px) scale(.96)', pointerEvents: 'none' }}/>
        )}
        {/* Current */}
        {cur && remaining > 0 && (
          <PostcardCard
            person={cur}
            drag={drag}
            style={{
              position: 'absolute', top: 10, left: 26, right: 26, bottom: 46,
              transform: `translate(${drag.dx}px, ${drag.dy}px) rotate(${drag.rot}deg)`,
              transition: drag.committing ? 'transform .26s cubic-bezier(.5,0,.6,1)' : 'transform .25s cubic-bezier(.2,.7,.3,1)',
              touchAction: 'none',
              cursor: drag.dx !== 0 ? 'grabbing' : 'grab',
            }}
          />
        )}
        {remaining === 0 && (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
            <div className="t-display" style={{ fontSize: 36 }}>All marked.</div>
            <div className="t-body" style={{ marginTop: 12 }}>{present} present · {absent} absent</div>
          </div>
        )}
      </div>

      {/* Single big action — swipe-to-confirm bar */}
      <div style={{ padding: '0 24px 28px', display: 'flex', alignItems: 'center', gap: 14 }}>
        <button onClick={() => drag.commit('left')} style={{ width: 56, height: 56, borderRadius: 18, background: 'color-mix(in oklch, var(--absent) 14%, var(--card))', color: 'var(--absent)', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{Ic.x(24)}</button>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 13, color: 'var(--ink-3)' }}>Swipe — or tap</div>
        <button onClick={() => drag.commit('right')} style={{ width: 56, height: 56, borderRadius: 18, background: 'var(--present)', color: 'var(--on-primary)', border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 10px 26px -10px color-mix(in oklch, var(--present) 70%, transparent)' }}>{Ic.check(24)}</button>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function PostcardCard({ person, style, drag }) {
  return (
    <div className="card" style={{ ...style, overflow: 'hidden', padding: 0 }}>
      {/* Top serial / ticket number */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderBottom: '1px dashed var(--hair)' }}>
        <div className="t-eyebrow">№ {String(person.id).padStart(4, '0')}</div>
        <div className="t-eyebrow" style={{ color: 'var(--ink-3)' }}>{person.family === '—' ? 'LONER' : person.family.toUpperCase()}</div>
      </div>

      {/* Editorial portrait area */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '40px 22px', position: 'relative', minHeight: 220 }}>
        <Avatar letter={person.first[0]} size={120}/>
        <div className="t-display" style={{ fontSize: 40, marginTop: 22, color: 'var(--ink)', textAlign: 'center', lineHeight: 1 }}>{person.first}</div>
        <div className="t-headline" style={{ fontSize: 22, color: 'var(--ink-2)', marginTop: 4 }}>{person.last}</div>

        {/* Stamps */}
        {drag && (
          <>
            <div className="stamp stamp-present" style={{ position: 'absolute', top: 24, right: 24, opacity: drag.stampPresent }}>Present</div>
            <div className="stamp stamp-absent" style={{ position: 'absolute', top: 24, left: 24, opacity: drag.stampAbsent }}>Absent</div>
          </>
        )}
      </div>

      {/* Signature line */}
      <div style={{ padding: '14px 20px', borderTop: '1px dashed var(--hair)', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ flex: 1, height: 1, background: 'var(--hair)' }}/>
        <span className="t-eyebrow" style={{ color: 'var(--ink-4)' }}>SIGN HERE</span>
        <div style={{ flex: 1, height: 1, background: 'var(--hair)' }}/>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Variation C — Ribbon (horizontal carousel with peek + tap-action)
// ─────────────────────────────────────────────────────────────
function SwipeDeckC({ theme = 'light' }) {
  const [idx, setIdx] = React.useState(0);
  const [marks, setMarks] = React.useState({}); // id -> 'present'|'absent'
  const totalP = Object.values(marks).filter(v => v === 'present').length;
  const totalA = Object.values(marks).filter(v => v === 'absent').length;
  const mark = (id, val) => {
    setMarks(m => ({ ...m, [id]: val }));
    setTimeout(() => setIdx(i => Math.min(i + 1, SAMPLE_PEOPLE.length - 1)), 280);
  };

  return (
    <div className="screen">
      <StatusBar/>
      <div className="app-header" style={{ padding: '10px 18px 6px' }}>
        <button className="icon-btn"><Ic.close/></button>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div className="t-eyebrow">Sunday Service</div>
          <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>{idx + 1} of {SAMPLE_PEOPLE.length}</div>
        </div>
        <button className="btn btn-ghost" style={{ padding: '8px 14px' }}>Done</button>
      </div>

      {/* Tally ribbon */}
      <div style={{ padding: '4px 18px 0', display: 'flex', gap: 8 }}>
        {SAMPLE_PEOPLE.map((p, i) => {
          const m = marks[p.id];
          return (
            <div key={p.id} style={{
              flex: 1, height: 6, borderRadius: 3,
              background: m === 'present' ? 'var(--present)' : m === 'absent' ? 'var(--absent)' : i === idx ? 'var(--ink-4)' : 'var(--bg-2)',
              opacity: m ? 1 : i === idx ? 0.6 : 0.5,
              transition: 'all .2s',
            }}/>
          );
        })}
      </div>

      {/* Ribbon carousel area */}
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        <div style={{
          position: 'absolute', top: 24, bottom: 24, left: 0,
          display: 'flex', gap: 14, padding: '0 80px',
          transform: `translateX(calc(50% - ${idx * 240}px - 50%))`,
          transition: 'transform .35s cubic-bezier(.2,.7,.3,1)',
        }}>
          {SAMPLE_PEOPLE.map((p, i) => {
            const m = marks[p.id];
            const isCur = i === idx;
            return (
              <div
                key={p.id}
                className="card"
                style={{
                  width: 240, flexShrink: 0, height: '100%',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                  padding: '32px 18px', gap: 14, position: 'relative',
                  transform: isCur ? 'scale(1)' : 'scale(.84)',
                  opacity: isCur ? 1 : 0.5,
                  transition: 'transform .35s, opacity .35s',
                }}>
                <Avatar letter={p.first[0]} size={isCur ? 96 : 64} tone={m === 'present' ? 'present' : m === 'absent' ? 'absent' : 'neutral'}/>
                <div style={{ textAlign: 'center' }}>
                  <div className="t-display" style={{ fontSize: isCur ? 28 : 22, color: 'var(--ink)' }}>{p.first}</div>
                  <div className="t-headline" style={{ fontSize: 16, color: 'var(--ink-2)' }}>{p.last}</div>
                  <div className="t-eyebrow" style={{ marginTop: 6 }}>{p.family === '—' ? 'Loner' : p.family}</div>
                </div>
                {m && (
                  <div className={`stamp ${m === 'present' ? 'stamp-present' : 'stamp-absent'}`} style={{ position: 'absolute', top: 18, right: 18, fontSize: 16, padding: '4px 10px' }}>
                    {m === 'present' ? 'Present' : 'Absent'}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Stats + actions */}
      <div style={{ padding: '0 22px 26px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, paddingBottom: 14 }}>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow" style={{ color: 'var(--present)' }}>Present</div>
            <div className="t-num" style={{ fontSize: 28, color: 'var(--present)' }}>{String(totalP).padStart(2, '0')}</div>
          </div>
          <div style={{ flex: 1, textAlign: 'right' }}>
            <div className="t-eyebrow" style={{ color: 'var(--absent)' }}>Absent</div>
            <div className="t-num" style={{ fontSize: 28, color: 'var(--absent)' }}>{String(totalA).padStart(2, '0')}</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 12 }}>
          <button onClick={() => mark(SAMPLE_PEOPLE[idx].id, 'absent')} className="btn btn-soft" style={{ flex: 1, padding: 16, color: 'var(--absent)', background: 'color-mix(in oklch, var(--absent) 10%, var(--card-soft))' }}>{Ic.x(20)} Absent</button>
          <button onClick={() => mark(SAMPLE_PEOPLE[idx].id, 'present')} className="btn btn-primary" style={{ flex: 1, padding: 16, background: 'var(--present)' }}>{Ic.check(20)} Present</button>
        </div>
      </div>
      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// List view — the "other half" of the Deck/List segmented control.
// Same header DNA as SwipeDeckA. Each row has thumb-sized ✓ / ✕
// taps that commit instantly + a third "skip" state. Sticky stat
// rail at top stays in sync. No scrolling needed for small rosters.
// ─────────────────────────────────────────────────────────────
function QuickList({ theme = 'light' }) {
  const [marks, setMarks] = React.useState({ 1: 'present', 2: 'present', 4: 'absent' });
  const set = (id, val) => setMarks(m => {
    if (m[id] === val) { const { [id]: _, ...rest } = m; return rest; }
    return { ...m, [id]: val };
  });
  const present = Object.values(marks).filter(v => v === 'present').length;
  const absent = Object.values(marks).filter(v => v === 'absent').length;
  const remaining = SAMPLE_PEOPLE.length - present - absent;

  return (
    <div className="screen">
      <StatusBar/>

      {/* Identical header to SwipeDeckA */}
      <div className="app-header" style={{ padding: '10px 18px 8px' }}>
        <button className="icon-btn"><Ic.close/></button>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div className="t-eyebrow">Sunday Service · 10:00</div>
          <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: 2 }}>
            <span style={{ color: 'var(--present)', fontWeight: 600 }}>{present}</span> · <span style={{ color: 'var(--absent)', fontWeight: 600 }}>{absent}</span> · <span style={{ fontWeight: 500 }}>{remaining} left</span>
          </div>
        </div>
        <button className="btn btn-ghost" style={{ padding: '8px 14px' }}>Done</button>
      </div>

      {/* Mode segmented — List is on */}
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 12px' }}>
        <div className="seg">
          <button><Ic.deck/> Deck</button>
          <button className="is-on"><Ic.list/> List</button>
        </div>
      </div>

      {/* Progress */}
      <div style={{ padding: '0 22px 10px' }}>
        <div style={{ height: 4, background: 'var(--bg-2)', borderRadius: 2, overflow: 'hidden', display: 'flex' }}>
          <div style={{ height: '100%', width: `${(present / SAMPLE_PEOPLE.length) * 100}%`, background: 'var(--present)' }}/>
          <div style={{ height: '100%', width: `${(absent / SAMPLE_PEOPLE.length) * 100}%`, background: 'var(--absent)' }}/>
        </div>
      </div>

      {/* Bulk + search row */}
      <div style={{ padding: '0 18px 10px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ flex: 1, background: 'var(--card-soft)', borderRadius: 12, padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 8, color: 'var(--ink-3)' }}>
          <Ic.search/>
          <span style={{ fontSize: 13 }}>Search names</span>
        </div>
        <button className="pill" style={{ padding: '9px 14px', whiteSpace: 'nowrap' }}>
          <Ic.checks/> All
        </button>
      </div>

      {/* Roster — quick-tap rows */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 14px 12px' }}>
        {SAMPLE_PEOPLE.map((p, i) => {
          const state = marks[p.id];
          const prevFam = i > 0 ? SAMPLE_PEOPLE[i - 1].family : null;
          const showSection = p.family !== prevFam;
          return (
            <React.Fragment key={p.id}>
              {showSection && (
                <div className="t-eyebrow" style={{
                  padding: '10px 6px 6px', color: 'var(--ink-3)',
                  display: 'flex', alignItems: 'center', gap: 8,
                }}>
                  <span style={{ width: 3, height: 11, background: 'currentColor', borderRadius: 2, opacity: 0.4 }}/>
                  {p.family === '—' ? 'Loners' : `${p.family} family`}
                </div>
              )}
              <QuickRow person={p} state={state} onSet={(v) => set(p.id, v)}/>
            </React.Fragment>
          );
        })}
      </div>

      <NavPill dark={theme === 'dark'}/>
    </div>
  );
}

function QuickRow({ person, state, onSet }) {
  const isP = state === 'present';
  const isA = state === 'absent';
  const tone = isP
    ? 'color-mix(in oklch, var(--present) 7%, var(--card))'
    : isA
    ? 'color-mix(in oklch, var(--absent) 6%, var(--card))'
    : 'var(--card)';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '8px 10px',
      borderRadius: 14,
      background: tone,
      transition: 'background .2s',
    }}>
      <Avatar letter={person.first[0]} size={40} tone={isP ? 'present' : isA ? 'absent' : 'neutral'}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{person.first} {person.last}</div>
        <div style={{ fontSize: 11, color: isP ? 'var(--present)' : isA ? 'var(--absent)' : 'var(--ink-3)', marginTop: 1, fontWeight: isP || isA ? 500 : 400 }}>
          {isP ? 'Present' : isA ? 'Absent' : 'Tap to mark'}
        </div>
      </div>
      {/* Two thumb-sized buttons */}
      <button
        onClick={() => onSet('absent')}
        aria-label="Mark absent"
        style={quickBtn(isA, 'absent')}>
        {Ic.x(20)}
      </button>
      <button
        onClick={() => onSet('present')}
        aria-label="Mark present"
        style={quickBtn(isP, 'present')}>
        {Ic.check(20)}
      </button>
    </div>
  );
}

function quickBtn(active, tone) {
  const color = tone === 'present' ? 'var(--present)' : 'var(--absent)';
  return {
    width: 44, height: 44, borderRadius: 12, border: 0, cursor: 'pointer',
    background: active ? color : `color-mix(in oklch, ${color} 10%, var(--card-soft))`,
    color: active ? 'var(--on-primary)' : color,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    transition: 'background .15s, transform .1s',
    boxShadow: active ? `0 8px 18px -10px color-mix(in oklch, ${color} 70%, transparent)` : 'none',
    flexShrink: 0,
  };
}

Object.assign(window, { SwipeDeckA, SwipeDeckB, SwipeDeckC, QuickList, SAMPLE_PEOPLE });
