install (FILES corebird.desktop            DESTINATION ${PREFIX}/share/applications/)
install (FILES fontawesome-webfont.ttf     DESTINATION ${PREFIX}/share/fonts/TTF/)

if (CATALOG)
  message ("CATALOG: ON")
  install (FILES corebird-catalog.xml DESTINATION ${PREFIX}/share/glade/catalogs/)
endif (CATALOG)

