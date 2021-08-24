using LibPeer.Networks.Simulation;

namespace ExponentialPinger {

    class Main : Object {

        public static int main(string[] args) {
            print("Exponential Pinger\n");
            int count = int.parse(args[1]);

            Conduit conduit = new Conduit();

            Pinger[] pingas = new Pinger[count];
            for (int i = 0; i < count; i++){
                pingas[i] = new Pinger(i, conduit);
            }

            while(true) {};

            return 0;
        }
    }

}