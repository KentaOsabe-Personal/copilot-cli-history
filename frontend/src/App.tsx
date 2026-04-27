import { Route, Routes } from 'react-router'

import AppShell from './app/AppShell.tsx'
import SessionDetailPage from './features/sessions/pages/SessionDetailPage.tsx'
import SessionIndexPage from './features/sessions/pages/SessionIndexPage.tsx'

function App() {
  return (
    <Routes>
      <Route path="/" element={<AppShell />}>
        <Route index element={<SessionIndexPage />} />
        <Route path="sessions/:sessionId" element={<SessionDetailPage />} />
      </Route>
    </Routes>
  )
}

export default App
