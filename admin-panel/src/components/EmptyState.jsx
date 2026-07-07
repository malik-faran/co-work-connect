import { EmptyPanel } from './ui/PageShell'

const EmptyState = ({ icon, title, message, action }) => (
  <div className="panel panel--padded">
    <EmptyPanel icon={icon} title={title} message={message} action={action} />
  </div>
)

export default EmptyState
