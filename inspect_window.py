import sys, glob
sys.path.insert(0, ".")
from aegis.static_analysis import analyze
p = glob.glob(sys.argv[1])[0]
f = analyze(p)
s = f.exposure_sites[0]
print("site:", s.function, "| call:", s.call)
print("before:", sorted(s.write_before_call))
print("after :", sorted(s.write_after_call))
# show the raw post-call source region
src = open(p).read()
import re
mm = re.search(r"function\s+%s\b" % re.escape(s.function), src)
if mm:
    body = src[mm.start():mm.start()+900]
    print("----- function source (head) -----")
    print(body)
