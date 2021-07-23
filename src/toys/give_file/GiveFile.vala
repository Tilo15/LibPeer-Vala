using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Networks;

using Gee;

namespace GiveFile {

    class FileGiver : Object {

        private Muxer muxer;
        private Network network;
        private Instance instance;
        private StreamTransmissionProtocol transport;
        private string path;
        private HashSet<InstanceReference> peers = new HashSet<InstanceReference>(r => r.hash(), (a, b) => a.compare(b) == 0);

        public FileGiver(Conduit conduit, string file_path) {
            muxer = new Muxer ();
            network = conduit.get_interface ();
            network.bring_up ();
            muxer.register_network (network);
            instance = muxer.create_instance ("GiveFile");
            transport = new StreamTransmissionProtocol (muxer, instance);
            path = file_path;

            instance.incoming_greeting.connect((origin) => rx_greeting(origin));
            network.incoming_advertisment.connect(rx_advertisement);
            transport.incoming_stream.connect(incoming);
            
            network.advertise(instance.reference);
            print(@"File giver created for '$path'\n");
        }

        void rx_advertisement(Advertisement adv) {
            print("rx_advertisement\n");
            if(!peers.contains(adv.instance_reference)) {
                var peer_info = new GLib.List<PeerInfo>();
                peer_info.append(adv.peer_info);
                muxer.inquire(instance, adv.instance_reference, peer_info);
            }
        }

        void rx_greeting(InstanceReference origin) {
            print("rx_greeting\n");
            peers.add(origin);
            transport.initialise_stream(origin).established.connect(make_request);
        }

        void make_request(StpOutputStream stream) {
            print("make_request\n");
            stream.reply.connect(reply);
            print("Asking peer to gib file\n");
            stream.write({'G', 'i', 'b', ' ', 'f', 'i', 'l', 'e'});
        }

        void reply(StpInputStream stream) {
            print("reply\n");
            print("Peer gibs file...\n");
            var reader = new DataInputStream(stream);
            var size = reader.read_uint32();
            var file = File.new_for_path(Uuid.string_random());
            var file_stream = file.create(FileCreateFlags.PRIVATE);
            uint8[] data = new uint8[size];
            reader.read(data);
            file_stream.write(data);
            file_stream.flush();
            file_stream.close();

            print("Done\n");
        }

        void incoming(StpInputStream stream) {
            print("incoming\n");
            print("I have a new stream\n");
            var magic = new uint8[8];
            uint8[] expected_magic = {'G', 'i', 'b', ' ', 'f', 'i', 'l', 'e'};
            stream.read(magic);
            for(var i = 0; i < 8; i++) {
                if(expected_magic[i] != magic[i]) {
                    print("Peer did not ask me to gib file\n");
                    return;
                }
            }

            transport.initialise_stream(stream.target, stream.session_id).established.connect(send_file);
        }

        void send_file(StpOutputStream stream) {
            print("send_file\n");
            print("Sending my file\n");
            var file = File.new_for_path(path);
            var file_stream = file.read();
            file_stream.seek(0, SeekType.END);
            var size = file_stream.tell();
            file_stream.seek(0, SeekType.SET);
            var writer = new DataOutputStream(stream);
            writer.put_uint32((uint32)size);
            var buffer = new uint8[size];
            file_stream.read(buffer);
            stream.write(buffer);
            file_stream.close();
        }

    }

}