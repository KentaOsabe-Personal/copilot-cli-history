import { useParams } from 'react-router'

function SessionDetailPage() {
  const sessionId = useParams().sessionId

  if (sessionId == null) {
    throw new Error('sessionId route param is required')
  }

  return (
    <section className="rounded-3xl border border-white/10 bg-slate-900/70 p-8">
      <h2 className="text-2xl font-semibold text-white">セッション詳細</h2>
      <p className="mt-4 text-sm leading-6 text-slate-300">
        詳細 route の直アクセスを有効化しました。詳細データの取得とタイムライン表示は後続タスクで接続します。
      </p>
      <dl className="mt-6 grid gap-3 text-sm text-slate-300 sm:grid-cols-[auto_1fr] sm:items-start">
        <dt className="font-medium text-slate-400">Session ID</dt>
        <dd className="font-mono text-cyan-200">{sessionId}</dd>
      </dl>
    </section>
  )
}

export default SessionDetailPage
