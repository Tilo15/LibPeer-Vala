dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    libpeer_dep
]

sources = files('Main.vala')
sources += files('Pinger.vala')

executable('exponential_pinger', sources, dependencies: dependencies)
