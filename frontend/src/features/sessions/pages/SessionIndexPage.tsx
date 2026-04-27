import SessionList from '../components/SessionList.tsx'
import StatusPanel from '../components/StatusPanel.tsx'
import { useSessionIndex } from '../hooks/useSessionIndex.ts'

function SessionIndexPage() {
  const { state } = useSessionIndex()

  return (
    <section className="flex flex-col gap-6">
      <h2 className="text-2xl font-semibold text-white">セッション一覧</h2>

      {state.status === 'loading' ? (
        <StatusPanel
          variant="loading"
          title="セッション一覧を読み込んでいます"
          message="保存済みセッションを確認しています。"
        />
      ) : null}

      {state.status === 'empty' ? (
        <StatusPanel
          variant="empty"
          title="セッションがありません"
          message="表示できるセッションはありません。"
        />
      ) : null}

      {state.status === 'error' ? (
        <StatusPanel
          variant="error"
          title="セッション一覧を表示できません"
          message="一覧の取得に失敗しました。時間をおいて再度開いてください。"
        />
      ) : null}

      {state.status === 'success' ? <SessionList sessions={state.sessions} /> : null}
    </section>
  )
}

export default SessionIndexPage
