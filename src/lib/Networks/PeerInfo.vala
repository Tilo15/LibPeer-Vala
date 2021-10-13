using GLib;
using Gee;
using LibPeer.Util;

namespace LibPeer.Networks
{
    
    public abstract class PeerInfo : Object {

        private static ConcurrentHashMap<Bytes, Type> info_types = new ConcurrentHashMap<Bytes, Type>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        
        protected abstract void build(uint8 data_length, InputStream stream) throws IOError, Error;
        
        public abstract Bytes get_network_identifier();

        protected abstract Bytes get_data_segment();

        public abstract string to_string();

        public abstract bool equals(PeerInfo other);

        public abstract uint hash();

        public void serialise(OutputStream stream) throws IOError, Error {
            // Create a stream writer
            var writer = new DataOutputStream(stream);
            writer.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Get the informational data
            var type = get_network_identifier();
            var data = get_data_segment();

            // Write the length of the network type
            writer.put_byte((uint8)type.length);

            // Write the length of the data segment
            writer.put_byte((uint8)data.length);

            // Write the network identifier
            writer.write_bytes(type);

            // Write the data
            writer.write_bytes(data);
        }
        
        public static PeerInfo deserialise(InputStream stream) throws IOError, Error {
            // Create a data input stream
            var reader = new DataInputStream(stream);
            reader.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Get the length of the network type
            var type_length = reader.read_byte();

            // Get the length of the data segment
            var data_length = reader.read_byte();

            // Read the network type
            var network_type = reader.read_bytes(type_length);

            //  Get the info subclass
            Type peer_info_type = typeof(UnknownPeerInfo);
            if(info_types.has_key(network_type)) {
                peer_info_type = info_types.get(network_type);
            }

            // Create the peer info object
            PeerInfo peer_info = Object.new(peer_info_type) as PeerInfo;

            // Build out the data
            peer_info.build(data_length, reader);

            // Return the object
            return peer_info;
        }

    }

}