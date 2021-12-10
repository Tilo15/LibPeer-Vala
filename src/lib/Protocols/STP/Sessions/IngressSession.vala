using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Segments;
using LibPeer.Util;
using Gee;

namespace LibPeer.Protocols.Stp.Sessions {

    public class IngressSession : Session {

        private uint64 next_expected_sequence_number = 0;

        private ConcurrentHashMap<uint64?, Payload> reconstruction = new ConcurrentHashMap<uint64?, Payload>(i => (uint)i, (a, b) => a == b);

        public signal void incoming_app_data(uint8[] data);

        public IngressSession(InstanceReference target, uint8[] session_id, uint64 ping) {
            base(target, session_id, ping);
            open = true;
        }

        public override void process_segment(Segment segment) {
            // We have received a segment from the muxer
            // Determine the segment type
            if(segment is Payload) {
                handle_payload((Payload)segment);
                return;
            }
            if(segment is Control) {
                handle_control((Control)segment);
                return;
            }
            
        }

        private void handle_payload(Payload segment) {
            // TODO: Feature handling
            // Is this a packet we are interested in?
            //  print(@"Expecting: $(next_expected_sequence_number), got $(segment.sequence_number)\n");
            if(next_expected_sequence_number <= segment.sequence_number) {
                // Add to reconstruction dictionary
                reconstruction.set(segment.sequence_number, segment);

                // Is this the next expected sequence number?
                if(next_expected_sequence_number == segment.sequence_number) {
                    // Reconstruct the data
                    incoming_app_data(complete_reconstruction());
                }
            }

            // Send an acknowledgement to the segment
            var acknowledgement = new Acknowledgement(segment);
            queue_segment(acknowledgement);
        }

        private void handle_control(Control segment) {
            // We have a control segment, what is it telling us?
            switch(segment.command) {
                case ControlCommand.COMPLETE:
                    close_session("The remote peer completed the stream");
                    break;
                case ControlCommand.ABORT:
                    close_session("The stream was aborted by the remote peer");
                    break;
                case ControlCommand.NOT_CONFIGURED:
                    close_session("The remote peer claims to not know about this session");
                    break;
            }
        }

        private uint8[] complete_reconstruction() {
            // Create a byte composer
            var composer = new Util.ByteComposer();

            // Start a counter
            uint64 sequence = next_expected_sequence_number;

            //  print(@"Reconstructing from seqno $(sequence)\n");
            
            // Loop until we don't have anything to reconstruct
            for (;reconstruction.has_key(sequence); sequence++) {
                // Get and remove the segment from the dictionary
                Payload segment;
                reconstruction.unset(sequence, out segment);
                
                // Compose
                composer.add_byte_array(segment.data);
            }

            //  print(@"$(next_expected_sequence_number) => $(sequence)\n");
            // Sequence is now the next expected sequence number
            next_expected_sequence_number = sequence;

            //  print(@"Reconstruction complete: \"$(composer.to_escaped_string())\"\n");

            // Return the composed reconstruction
            return composer.to_byte_array();
        }
    }

}