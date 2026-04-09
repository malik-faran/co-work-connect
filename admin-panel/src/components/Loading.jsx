import { useEffect, useRef } from 'react'

const Loading = ({ message = 'Loading...' }) => {
  const spinnerRef = useRef(null)

  useEffect(() => {
    const el = spinnerRef.current
    if (!el) return

    let rafId
    let angle = 0
    const step = () => {
      angle = (angle + 6) % 360
      el.style.transform = `rotate(${angle}deg)`
      rafId = requestAnimationFrame(step)
    }
    rafId = requestAnimationFrame(step)
    return () => cancelAnimationFrame(rafId)
  }, [])

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '400px',
      gap: '16px'
    }}>
      <div
        ref={spinnerRef}
        style={{
          width: '48px',
          height: '48px',
          border: '4px solid #e5e7eb',
          borderTop: '4px solid #3b82f6',
          borderRadius: '50%'
        }}
      />
      <p style={{ color: '#64748b', fontSize: '14px' }}>{message}</p>
    </div>
  )
}

export default Loading
