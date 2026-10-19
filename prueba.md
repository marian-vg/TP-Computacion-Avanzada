git checkout -- monitor.sh
cat << 'EOF' > parche.sh
awk '
/while true; do/ {
    print $0
    print "        salida=$("
    next
}
/echo -e ".*Atajos.*/ {
    print "        )"
    print "        clear"
    print "        echo \"$salida\""
    print $0
    next
}
/^[ \t]*clear[ \t]*$/ {
    next
}
{ print $0 }
' monitor.sh > temp.sh && mv temp.sh monitor.sh && chmod +x monitor.sh
EOF
bash parche.sh
