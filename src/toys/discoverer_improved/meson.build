dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    meson.get_compiler('vala').find_library('posix'),
    libpeer_dep
]

sources = files('Main.vala')
sources += files('Discoverer.vala')

executable('discoverer2', sources, dependencies: dependencies)

sources = files('MainIP.vala')
sources += files('Discoverer.vala')

executable('discoverer2_ipv4', sources, dependencies: dependencies)

sources = files('MainRouted.vala')
sources += files('Discoverer.vala')

executable('discoverer2_routed', sources, dependencies: dependencies)
