using LibPeer.Util;
using LibPeer.Networks;

namespace LibPeer.Protocols.Mx2 {

    public class Fragmenter {

        private uint64 message_seqn = 0;

        public void send_frame(Frame frame, Instance instance, Network network, PeerInfo info) throws IOError, Error {
            // Get the size for the fragments
            var fragment_size = network.get_mtu() - Fragment.HEADER_LENGTH;

            // Serialise the entire frame
            MemoryOutputStream stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            frame.serialise(stream, instance);
            stream.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();
            
            // Calculate number of needed fragments
            uint32 fragment_count = (buffer.length / fragment_size) + uint32.min(buffer.length % fragment_size, 1);

            lock(message_seqn) {
                try {
                    // Create the fragments and send them
                    for(uint32 i = 0; i < fragment_count; i++) {
                        var fragment = new Fragment(message_seqn, i, fragment_count, buffer[i*fragment_size : uint32.min((i+1)*fragment_size, buffer.length)]);
                        network.send_with_stream(info, fragment.serialise);
                    }
                }
                finally {
                    message_seqn++;
                }
            }
        }

    }

}