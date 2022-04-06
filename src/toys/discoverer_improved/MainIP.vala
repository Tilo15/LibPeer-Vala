using LibPeer.Networks.IPv4;

namespace Discoverer {

    class Main : Object {

        public static int main(string[] args) {
            print("Discoverer (IPv4)\n");
            string address = args[1];
            uint16 port = (uint16)int.parse(args[2]);

            var worker = new DiscoverWorker(0, new IPv4(address, port));

            while(true) {}

            return 0;
        }
    }

}