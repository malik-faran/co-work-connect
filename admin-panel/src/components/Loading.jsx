const Loading = ({ message = 'Loading...' }) => (
  <div className="loading-screen">
    <div className="loading-ring" />
    <p style={{ color: 'var(--text-secondary)', fontSize: 14 }}>{message}</p>
  </div>
)

export default Loading
