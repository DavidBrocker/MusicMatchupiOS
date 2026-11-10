const { useScene, SceneStage } = window;
const { useTweaks, TweaksPanel, TweakSection, TweakToggle, TweakRadio } = window;

function seededRandom(seed) { let s = seed; return () => { s = (s * 9301 + 49297) % 233280; return s / 233280; }; }
const rand = seededRandom(42);
const STARS = Array.from({ length: 140 }, () => ({
  x: rand() * 1080, y: rand() * 1920, r: 0.8 + rand() * 1.8, o: 0.15 + rand() * 0.35
}));

const LOGO_D = "m 11.724001,106.19116 0.185825,-76.781979 34.899565,20.982284 34.51696,-21.974879 0.564563,63.76259 -7.043328,-0.02472 -0.08538,-52.806862 -27.989454,18.277925 -27.982183,-18.189475 -0.08075,66.769576 z m 13.868965,0.0152 0.22683,-55.801687 21.045214,14.154547 20.992827,-14.353308 0.0016,49.049805 20.987098,-0.01457 0.03358,-77.144504 -77.050169,0.07657 -0.04294,-7.058821 84.251159,0.0091 -0.318456,91.195528 -34.85205,-0.16684 0.07893,-44.916462 L 46.977865,71.424819 32.97228,61.670603 32.620322,106.24317 Z";
const LOGO_VB_W = 84.815628, LOGO_VB_H = 91.705856;
const LOGO_CX = 540, LOGO_CY = 740, LOGO_H = 380;
const LOGO_SCALE = LOGO_H / LOGO_VB_H;
const LOGO_W = LOGO_VB_W * LOGO_SCALE;
const LOGO_OX = LOGO_CX - LOGO_W / 2;
const LOGO_OY = LOGO_CY - LOGO_H / 2;

const ACCENTS = { plum: "#cf9fc2", indigo: "#9fb0e6", teal: "#8fd0c9" };

const NODES = [
  { angle: -100, dist: 300, r: 7 },
  { angle: -28, dist: 345, r: 5 },
  { angle: 42, dist: 315, r: 6 },
  { angle: 112, dist: 335, r: 5 },
  { angle: 192, dist: 300, r: 6 }
].map((n, i) => ({
  ...n,
  x: LOGO_CX + Math.cos(n.angle * Math.PI / 180) * n.dist,
  y: LOGO_CY + Math.sin(n.angle * Math.PI / 180) * n.dist,
  delay: i * 0.12
}));

function easeOutCubic(t) { return 1 - Math.pow(1 - t, 3); }
function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

const AccentContext = React.createContext(ACCENTS.plum);
const SubtitleContext = React.createContext(true);

function Backdrop() {
  return (
    <React.Fragment>
      <defs>
        <radialGradient id="bgGrad" cx="50%" cy="38%" r="75%">
          <stop offset="0%" stopColor="#241128" />
          <stop offset="60%" stopColor="#160a17" />
          <stop offset="100%" stopColor="#0a0509" />
        </radialGradient>
      </defs>
      <rect x="0" y="0" width="1080" height="1920" fill="url(#bgGrad)" />
    </React.Fragment>
  );
}

function Stars({ opacity }) {
  return (
    <g opacity={opacity}>
      {STARS.map((s, i) => <circle key={i} cx={s.x} cy={s.y} r={s.r} fill="#ffffff" opacity={s.o} />)}
    </g>
  );
}

function Glow({ opacity, color }) {
  return <circle cx={LOGO_CX} cy={LOGO_CY} r="260" fill={color} opacity={opacity * 0.22} style={{ filter: "blur(60px)" }} />;
}

function Logo({ drawP, fillOpacity, strokeOpacity }) {
  return (
    <g transform={`translate(${LOGO_OX}, ${LOGO_OY}) scale(${LOGO_SCALE})`}>
      <g transform="translate(-11.473396,-14.864364)">
        <path d={LOGO_D} fill="#ffffff" fillOpacity={fillOpacity}
          stroke="#ffffff" strokeOpacity={strokeOpacity} strokeWidth="1.4"
          pathLength="1" strokeDasharray="1" strokeDashoffset={1 - drawP} />
      </g>
    </g>
  );
}

function NodesLayer({ progress, color }) {
  return (
    <g>
      {NODES.map((n, i) => {
        const win = 0.4;
        const lineT = easeOutCubic(clamp01((progress - n.delay) / win));
        const nodeT = easeOutCubic(clamp01((progress - n.delay - 0.08) / win));
        return (
          <g key={i}>
            <line x1={LOGO_CX} y1={LOGO_CY} x2={n.x} y2={n.y} stroke={color} strokeWidth="1.5"
              opacity={lineT * 0.7} pathLength="1" strokeDasharray="1" strokeDashoffset={1 - lineT} />
            <circle cx={n.x} cy={n.y} r={n.r * nodeT} fill={color} opacity={nodeT} />
          </g>
        );
      })}
    </g>
  );
}

function Frame({ children }) {
  return (
    <div style={{ width: 1080, height: 1920, position: "relative", background: "#0a0509", overflow: "hidden" }}>
      <svg width="1080" height="1920" style={{ position: "absolute", inset: 0 }}>{children}</svg>
    </div>
  );
}

function Void() {
  const { progress } = useScene();
  return <Frame><Backdrop /><Stars opacity={clamp01(progress / 0.8)} /></Frame>;
}

function Draw() {
  const { progress } = useScene();
  const accent = React.useContext(AccentContext);
  const drawP = easeOutCubic(clamp01(progress / 0.55));
  const fillP = clamp01((progress - 0.45) / 0.4);
  return (
    <Frame>
      <Backdrop /><Stars opacity={1} />
      <Glow opacity={fillP} color={accent} />
      <Logo drawP={drawP} fillOpacity={fillP} strokeOpacity={1 - fillP} />
    </Frame>
  );
}

function Constellation() {
  const { progress } = useScene();
  const accent = React.useContext(AccentContext);
  return (
    <Frame>
      <Backdrop /><Stars opacity={1} />
      <Glow opacity={1} color={accent} />
      <Logo drawP={1} fillOpacity={1} strokeOpacity={0} />
      <NodesLayer progress={progress} color={accent} />
    </Frame>
  );
}

function Wordmark() {
  const { progress } = useScene();
  const accent = React.useContext(AccentContext);
  const showSubtitle = React.useContext(SubtitleContext);
  const titleT = easeOutCubic(clamp01(progress / 0.5));
  const subT = easeOutCubic(clamp01((progress - 0.35) / 0.4));
  return (
    <div style={{ width: 1080, height: 1920, position: "relative", background: "#0a0509", overflow: "hidden" }}>
      <svg width="1080" height="1920" style={{ position: "absolute", inset: 0 }}>
        <Backdrop /><Stars opacity={1} />
        <Glow opacity={1} color={accent} />
        <Logo drawP={1} fillOpacity={1} strokeOpacity={0} />
        <NodesLayer progress={1} color={accent} />
      </svg>
      <div style={{ position: "absolute", left: 0, top: 1260, width: 1080, display: "flex", flexDirection: "column", alignItems: "center", gap: 14 }}>
        <div style={{ fontFamily: "-apple-system, 'Helvetica Neue', Arial, sans-serif", fontWeight: 700, fontSize: 58, color: "#ffffff", letterSpacing: `${(1 - titleT) * 10 + 0.5}px`, opacity: titleT }}>MusicMatchup</div>
        {showSubtitle && (
          <div style={{ fontFamily: "-apple-system, 'Helvetica Neue', Arial, sans-serif", fontWeight: 400, fontSize: 24, color: "rgba(255,255,255,0.55)", opacity: subT }}>See how your music connects</div>
        )}
      </div>
    </div>
  );
}

function MMSplash() {
  const [t, setTweak] = useTweaks(window.TWEAK_DEFAULTS);
  const accent = ACCENTS[t.accentTone] || ACCENTS.plum;
  return (
    <AccentContext.Provider value={accent}>
      <SubtitleContext.Provider value={t.showSubtitle}>
        <SceneStage width={1080} height={1920} scenes={window.OM_SCENES} playback={window.OM_PLAYBACK} bg="#0a0509">
          {{ Void, Draw, Constellation, Wordmark }}
        </SceneStage>
        <TweaksPanel>
          <TweakToggle label="Motion editor" value={t.motionEditor} onChange={(v) => setTweak('motionEditor', v)} />
          <TweakSection label="Accent" />
          <TweakRadio label="Tone" value={t.accentTone} options={['plum', 'indigo', 'teal']} onChange={(v) => setTweak('accentTone', v)} />
          <TweakToggle label="Show subtitle" value={t.showSubtitle} onChange={(v) => setTweak('showSubtitle', v)} />
        </TweaksPanel>
      </SubtitleContext.Provider>
    </AccentContext.Provider>
  );
}
window.MMSplash = MMSplash;
