using LibPeer.Protocols.Stp.Streams;


namespace LibPeer.Util {

    public class SyncStreamWaiter {

        private Gee.LinkedList<StpInputStream> streams = new Gee.LinkedList<StpInputStream>();

        private Cond cond = Cond();
        private Mutex mutex = Mutex();
        private StpInputStream? notified_stream = null;
        public signal void stream_closed(StpInputStream stream);

        public void add_stream(StpInputStream stream) {
            streams.add(stream);
            stream.new_data.connect(handle_signal);
        }

        private void handle_signal(StpInputStream sender) {
            if(sender.is_closed()) {
                streams.remove(sender);
                stream_closed(sender);
                if(!sender.has_unread_data) {
                    return;
                }
            }

            mutex.lock();
            notified_stream = sender;
            cond.broadcast();
            mutex.unlock();
        }

        public StpInputStream wait_for_next() {
            // Quick active check of all streams
            foreach(var s in streams) {
                if(s.has_unread_data) {
                    return s;
                }
            }

            // Otherwise wait for signal
            mutex.lock();
            StpInputStream? stream = null;
            while(stream == null) {
                cond.wait(mutex);
                stream = notified_stream;
            }
            notified_stream = null;
            mutex.unlock();
            return stream;
        }

    }

    public class MappedSyncStreamWaiter<T> {
        
        private SyncStreamWaiter waiter = new SyncStreamWaiter();
        private HashTable<StpInputStream, T> table = new HashTable<StpInputStream, T>(direct_hash, direct_equal);
        public signal void stream_closed(StpInputStream stream);

        public MappedSyncStreamWaiter() {
            waiter.stream_closed.connect(on_stream_closed);
        }

        private void on_stream_closed(StpInputStream stream) {
            table.remove(stream);
            stream_closed(stream);
        }

        public void add_stream(StpInputStream stream, T mapped_obj) {
            table[stream] = mapped_obj;
            waiter.add_stream(stream);
        }

        public T wait_for_next() {
            var stream = waiter.wait_for_next();
            return table[stream];
        }

    }

}