using LibPeer;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Protocols.Mx2;
using LibPeer.Util;

namespace HelloWorldApp {

    class Main : PeerApplication {

        private uint8[] message = new uint8[] { 'H', 'e', 'l', 'l', 'o', ',', 'w', 'o', 'r', 'l', 'd', '!' };

        public override string application_namespace { get { return "hello-world"; }}

        public static int main(string[] args) {
            var t = new Main();
            while (true) {};
            return 0;
        }
        
        protected override void on_incoming_stream (StpInputStream stream) {
            var message_length = new uint8[1];
            stream.read (message_length);
            var message = new uint8[message_length[0]];
            stream.read(message);

            print(@"A peer has made a connection to us! It has a message: \"$(new ByteComposer().add_byte_array(message).to_escaped_string())\"\n");

            reply_to_stream(stream).established.connect (s => acknowledge_message(s));
        }

        protected override void on_peer_available (InstanceReference peer) {
            print("A new peer is available!\n");
            establish_stream (peer).established.connect (send_message);
        }

        private void send_message(StpOutputStream stream) {
            print("I'm sending the peer a message\n");
            var data = new ByteComposer().add_byte((uint8)message.length).add_byte_array(message).to_byte_array();
            stream.write (data);
            stream.close();
            stream.reply.connect(on_reply);
        }

        private void on_reply(StpInputStream stream) {
            var data = new uint8[6];
            stream.read(data);
            stream.close();
            print(@"Remote peer says \"$(new ByteComposer().add_byte_array(data).to_escaped_string())\" for the message!\n");
        }

        private void acknowledge_message(StpOutputStream stream) {
            stream.write (new uint8[] {'T', 'h', 'a', 'n', 'k', 's'});
            stream.close();
            print("I told them thanks for the message!\n");
        }

    }



}