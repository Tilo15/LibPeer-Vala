using LibPeer.Util;
using LibPeer.Networks;

namespace LibPeer.Protocols.Mx2 {

    public class Assembler {

        private HashTable<string, HashTable<string, Fragment>> frag_table = new HashTable<string, HashTable<string, Fragment>>(str_hash, str_equal);


        public InputStream? handle_data(InputStream stream) throws IOError, Error {
            // Read the fragment
            var fragment = new Fragment.from_stream(stream);

            // Do we have this message?
            var message_id = fragment.message_number.to_string();
            if(!frag_table.contains(message_id)) {
                // No, create a table for it
                frag_table[message_id] = new HashTable<string, Fragment>(str_hash, str_equal);
            }

            // Get the message table
            var message_table = frag_table[message_id];

            // Save the fragment in the table
            message_table[fragment.fragment_number.to_string()] = fragment;

            // Is the table now complete?
            if(message_table.size() == fragment.total_fragments) {
                // Yes, complete it
                var composer = new ByteComposer();
                for(var i = 0; i < fragment.total_fragments; i++) {
                    composer.add_byte_array(message_table[i.to_string()].payload);
                }
                
                frag_table.remove(message_id);
                return composer.to_stream();
            }

            return null;
        }

    }

}