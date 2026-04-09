const EmptyState = ({ icon: Icon, title, message }) => {
  return (
    <div style={{
      backgroundColor: 'white',
      padding: '60px 40px',
      borderRadius: '12px',
      textAlign: 'center',
      boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)'
    }}>
      {Icon && (
        <div style={{
          width: '80px',
          height: '80px',
          borderRadius: '50%',
          backgroundColor: '#f1f5f9',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 24px'
        }}>
          <Icon size={40} color="#cbd5e1" />
        </div>
      )}
      <h3 style={{
        fontSize: '20px',
        fontWeight: '600',
        color: '#1e293b',
        marginBottom: '8px'
      }}>
        {title}
      </h3>
      <p style={{
        color: '#64748b',
        fontSize: '14px',
        maxWidth: '400px',
        margin: '0 auto'
      }}>
        {message}
      </p>
    </div>
  )
}

export default EmptyState

