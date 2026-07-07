const QueryBanner = ({ error, hint }) => {
  if (!error) return null
  return (
    <div className="alert-error" style={{ marginBottom: 20 }}>
      <strong style={{ display: 'block', marginBottom: 4 }}>Could not load data</strong>
      <span>{error}</span>
      {hint && (
        <p style={{ margin: '8px 0 0', fontSize: 12, opacity: 0.9 }}>{hint}</p>
      )}
    </div>
  )
}

export default QueryBanner
