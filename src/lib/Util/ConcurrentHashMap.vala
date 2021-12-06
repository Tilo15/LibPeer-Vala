using Gee;

namespace LibPeer.Util {

    public class ConcurrentHashMap<K, V> : AbstractMap<K,V> {

        private HashMap<K, V> _map;

        private HashDataFunc<K>? key_hash_func = null;
        private EqualDataFunc<K>? key_equal_func = null;
        private EqualDataFunc<V>? value_equal_func = null;

        public ConcurrentHashMap (owned HashDataFunc<K>? key_hash_func = null, owned EqualDataFunc<K>? key_equal_func = null, owned EqualDataFunc<V>? value_equal_func = null) {
            _map = new HashMap<K, V> (key_hash_func, key_equal_func, value_equal_func);
            this.key_hash_func = key_hash_func;
            this.key_equal_func = key_equal_func;
            this.value_equal_func = value_equal_func;
        }

        private HashMap<K, V> copy() {
            lock(_map) {
                HashMap<K, V> copy = new HashMap<K, V> (key_hash_func, key_equal_func, value_equal_func);
                copy.set_all(_map);
                return copy;
            }
        }

        public override void clear () {
            lock(_map) {
                _map.clear();
            }
        }
		/**
		 * {@inheritDoc}
		 */
		public override new V @get (K key) {
            lock(_map) {
                return _map.get (key);
            }
        }
		/**
		 * {@inheritDoc}
		 */
		public override bool has (K key, V value) {
            lock(_map) {
                return _map.has (key, value);
            }
        }
		/**
		 * {@inheritDoc}
		 */
		public override bool has_key (K key)  {
            lock(_map) {
                return _map.has_key (key);
            }
        }
		/**
		 * {@inheritDoc}
		 */
		public override Gee.MapIterator<K,V> map_iterator () {
            return copy().map_iterator();
        }

		/**
		 * {@inheritDoc}
		 */
		public override new void @set (K key, V value)  {
            lock(_map) {
                _map.set (key, value);
            }
        }
		/**
		 * {@inheritDoc}
		 */
		public override bool unset (K key, out V value = null)  {
            lock(_map) {
                return _map.unset (key, out value);
            }
        }
		/**
		 * {@inheritDoc}
		 */
		public override Gee.Set<Gee.Map.Entry<K,V>> entries { owned get {
            return copy().entries;
        } }
		/**
		 * {@inheritDoc}
		 */
		public override Gee.Set<K> keys { owned get {
            return copy().keys;
        } }
		/**
		 * {@inheritDoc}
		 */
		public override bool read_only { get {
            lock(_map) {
                return _map.read_only;
            }
        } }
		/**
		 * {@inheritDoc}
		 */
		public override int size { get {
            lock(_map) {
                return _map.size;
            }
        } }
		/**
		 * {@inheritDoc}
		 */
		public override Gee.Collection<V> values { owned get {
            return copy().values;
        } }

    }

}