using LibPeer.Util;
using LibPeer.Networks;

namespace LibPeer.Protocols.Mx2 {

    public class Assembler {

        private uint64 message_id = uint64.MAX;

        private uint32 fragment_seqn = 0;

        private uint32 fragment_count = 0;

        private ByteComposer composer = new ByteComposer();

        private bool success = false;

        public InputStream? handle_data(InputStream stream) throws IOError, Error {
            // Read the fragment
            var fragment = new Fragment.from_stream(stream);
            
            // Are we currently reading this message?
            if(fragment.message_number != message_id) {
                // No, reset and start reading
                reset(fragment);
            }

            // Is this the next expected sequence number?
            if(fragment.fragment_number != fragment_seqn) {
                //  print("Dropped or out of order fragment\n");
                // No, we may have lost one. Drop
                return null;
            }

            // Increment next expected sequence number
            fragment_seqn ++;

            // Add the fragment data
            composer.add_byte_array(fragment.payload);

            // Is this the last fragment for this message?
            if(fragment_seqn == fragment_count) {
                // Yes, create a memory stream and return
                //  print(@"Message $(message_id) assembled\n");
                success = true;
                return new MemoryInputStream.from_data(composer.to_byte_array());
            }

            // Nothing to return yet
            return null;
        }

        private void reset(Fragment fragment) {
            if(!success) {
                //  print(@"Message $(message_id) dropped\n");
            }
            message_id = fragment.message_number;
            fragment_seqn = 0;
            fragment_count = fragment.total_fragments;
            composer = new ByteComposer();
            success = false;
        }

    }

}