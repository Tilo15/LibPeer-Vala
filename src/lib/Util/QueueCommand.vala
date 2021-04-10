namespace LibPeer.Util {

    public enum QueueControl {
        Payload,
        Stop,
    }

    public class QueueCommand<T> {

        public T payload;

        public QueueControl command;

        public QueueCommand(QueueControl command, T payload) {
            this.payload = payload;
            this.command = command;
        }

        public QueueCommand.stop() {
            this(QueueControl.Stop, null);
        }

        public QueueCommand.with_payload(T payload){
            this(QueueControl.Payload, payload);
        }

    }

}