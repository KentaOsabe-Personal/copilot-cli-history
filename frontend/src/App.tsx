function App() {
  return (
    <main className="min-h-screen bg-slate-950 px-6 py-16 text-slate-100">
      <div className="mx-auto flex max-w-5xl flex-col gap-8">
        <div className="inline-flex w-fit rounded-full border border-cyan-400/30 bg-cyan-400/10 px-3 py-1 text-sm font-medium text-cyan-200">
          Phase 1 environment ready
        </div>

        <div className="grid gap-6 lg:grid-cols-[2fr_1fr]">
          <section className="rounded-3xl border border-white/10 bg-white/5 p-8 shadow-2xl shadow-slate-950/40">
            <p className="text-sm uppercase tracking-[0.24em] text-slate-400">
              Copilot CLI Session History
            </p>
            <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white md:text-5xl">
              React, Rails, and MySQL are wired together in Docker.
            </h1>
            <p className="mt-4 max-w-2xl text-base leading-7 text-slate-300">
              This frontend runs on Vite with React 19, TypeScript 6, Vitest, and Tailwind CSS 4.
              The next phases can focus on reading and visualizing Copilot CLI session history.
            </p>
          </section>

          <section className="rounded-3xl border border-white/10 bg-slate-900/80 p-6">
            <h2 className="text-lg font-semibold text-white">Ports</h2>
            <dl className="mt-4 space-y-4 text-sm text-slate-300">
              <div className="flex items-center justify-between gap-4">
                <dt>Frontend</dt>
                <dd className="font-mono text-cyan-200">51730</dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt>Backend</dt>
                <dd className="font-mono text-cyan-200">30000</dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt>MySQL</dt>
                <dd className="font-mono text-cyan-200">33006</dd>
              </div>
            </dl>
          </section>
        </div>
      </div>
    </main>
  )
}

export default App
