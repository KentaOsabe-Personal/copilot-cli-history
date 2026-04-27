import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'

import App from './App'

describe('App', () => {
  it('renders the session index route inside the shared read-only shell', () => {
    render(
      <MemoryRouter initialEntries={['/']}>
        <App />
      </MemoryRouter>,
    )

    expect(
      screen.getByRole('heading', {
        name: 'Copilot CLI Session History',
      }),
    ).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'セッション一覧' })).toHaveAttribute('href', '/')
    expect(screen.getByRole('heading', { name: 'セッション一覧' })).toBeInTheDocument()
    expect(screen.getByText('この画面は閲覧専用です。')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: '検索' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: '絞り込み' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: '再読み込み' })).not.toBeInTheDocument()
  })

  it('renders the detail route directly without going through the index page', () => {
    render(
      <MemoryRouter initialEntries={['/sessions/session-123']}>
        <App />
      </MemoryRouter>,
    )

    expect(screen.getByRole('heading', { name: 'セッション詳細' })).toBeInTheDocument()
    expect(screen.getByText('session-123')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'セッション一覧' })).toHaveAttribute('href', '/')
  })
})
