using LibPeer.Networks.Simulation;

namespace Discoverer {

    class Main : Object {

        public static int main(string[] args) {
            print("Discoverer\n");
            int count = int.parse(args[1]);

            Conduit conduit = new Conduit();

            DiscoverWorker[] pingas = new DiscoverWorker[count];
            for (int i = 0; i < count; i++){
                pingas[i] = new DiscoverWorker(i, conduit);
            }

            while(true) {};

            return 0;
        }
    }

}