import { render, screen } from '@testing-library/react'

import App from './App'

describe('App', () => {
  it('renders the phase 1 heading', () => {
    render(<App />)

    expect(
      screen.getByRole('heading', {
        name: /react, rails, and mysql are wired together in docker\./i,
      }),
    ).toBeInTheDocument()
    expect(screen.getByText('51730')).toBeInTheDocument()
  })
})
