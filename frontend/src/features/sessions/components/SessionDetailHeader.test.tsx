import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'

import {
  buildSessionUiDetail,
  sessionUiDetailScenarios,
} from '../testing/sessionUiTestData.ts'
import SessionDetailHeader from './SessionDetailHeader.tsx'

describe('SessionDetailHeader', () => {
  it('shows only real metadata values for an ordinary complete session', () => {
    render(
      <MemoryRouter>
        <SessionDetailHeader
          detail={buildSessionUiDetail({
            id: 'detail-complete',
            source_state: 'complete',
            degraded: false,
            issues: [],
          })}
        />
      </MemoryRouter>,
    )

    expect(screen.getByText('octo/copilot-cli-history @ main')).toBeInTheDocument()
    expect(screen.getByText('gpt-5-current')).toBeInTheDocument()
    expect(screen.queryByText('正常')).not.toBeInTheDocument()
    expect(screen.queryByText('workspace-only')).not.toBeInTheDocument()
  })

  it('omits placeholder-only metadata without leaving normal-state badges behind', () => {
    render(
      <MemoryRouter>
        <SessionDetailHeader detail={sessionUiDetailScenarios.missingWorkContextAndModel} />
      </MemoryRouter>,
    )

    expect(screen.queryByText('作業コンテキスト不明')).not.toBeInTheDocument()
    expect(screen.queryByText('モデル不明')).not.toBeInTheDocument()
    expect(screen.queryByText('正常')).not.toBeInTheDocument()
  })

  it('keeps degraded and workspace-only constraints visible in the header', () => {
    const { rerender } = render(
      <MemoryRouter>
        <SessionDetailHeader detail={sessionUiDetailScenarios.workspaceOnly} />
      </MemoryRouter>,
    )

    expect(screen.getByText('workspace-only')).toBeInTheDocument()
    expect(screen.queryByText('正常')).not.toBeInTheDocument()

    rerender(
      <MemoryRouter>
        <SessionDetailHeader detail={sessionUiDetailScenarios.interactionSurface} />
      </MemoryRouter>,
    )

    expect(screen.getByText('一部欠損あり')).toBeInTheDocument()
  })
})
