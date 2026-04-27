import { useParams } from 'react-router'

import IssueList from '../components/IssueList.tsx'
import SessionDetailHeader from '../components/SessionDetailHeader.tsx'
import SessionTimeline from '../components/SessionTimeline.tsx'
import StatusPanel from '../components/StatusPanel.tsx'
import { useSessionDetail } from '../hooks/useSessionDetail.ts'

function SessionDetailPage() {
  const sessionId = useParams().sessionId

  if (sessionId == null) {
    throw new Error('sessionId route param is required')
  }

  const { state } = useSessionDetail(sessionId)

  return (
    <section className="flex flex-col gap-6">
      <h2 className="text-2xl font-semibold text-white">セッション詳細</h2>
      <p className="font-mono text-sm text-cyan-200">{sessionId}</p>

      {state.status === 'loading' ? (
        <StatusPanel
          variant="loading"
          title="セッション詳細を読み込んでいます"
          message="セッションのタイムラインを確認しています。"
        />
      ) : null}

      {state.status === 'not_found' ? (
        <StatusPanel
          variant="not_found"
          title="セッションが見つかりません"
          message="指定されたセッションは存在しないか、すでに参照できません。"
          showSessionIndexLink
        />
      ) : null}

      {state.status === 'error' ? (
        <StatusPanel
          variant="error"
          title="セッション詳細を表示できません"
          message="詳細の取得に失敗しました。セッション一覧に戻って対象を選び直してください。"
          showSessionIndexLink
        />
      ) : null}

      {state.status === 'success' ? (
        <>
          <SessionDetailHeader detail={state.detail} />
          <IssueList title="セッションの issue" issues={state.detail.issues} />
          <SessionTimeline timeline={state.detail.timeline} />
        </>
      ) : null}
    </section>
  )
}

export default SessionDetailPage
