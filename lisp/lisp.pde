char kLPar = '(';
char kRPar = ')';
char kQuote = '\'';

int NIL = 0;
int NUM = 1;
int SYM = 2;
int ERROR = 3;
int CONS = 4;
int SUBR = 5;
int EXPR = 6;

class LObj {
  int tag;
  Object data;
  LObj(int t, Object o) {
    tag = t;
    data = o;
  }

  Integer num() { return (Integer)data; }
  String str() { return (String)data; }
  Cons cons() { return (Cons)data; }
  Subr subr() { return (Subr)data; }
  Expr expr() { return (Expr)data; }

  String toString() {
    if (tag == NIL) { return "nil"; }
    else if (tag == NUM) {
      return num().toString();
    } else if (tag == SYM) {
      return str();
    } else if (tag == ERROR) {
      return "<error: " + str() + ">";
    } else if (tag == CONS) {
      return listToString(this);
    } else if (tag == SUBR) {
      return "<subr>";
    } else if (tag == EXPR) {
      return "<expr>";
    } else {
      return "<unknown>";
    }
  }

  String listToString(LObj obj) {
    String ret = "";
    boolean first = true;
    while (obj.tag == CONS) {
      if (first) {
        first = false;
      } else {
        ret += " ";
      }
      ret += obj.cons().car.toString();
      obj = obj.cons().cdr;
    }
    if (obj == kNil) {
      return "(" + ret + ")";
    }
    return "(" + ret + " . " + obj.toString() + ")";
  }
}

class Cons {
  LObj car;
  LObj cdr;
  Cons(LObj a, LObj d) {
    car = a;
    cdr = d;
  }
}

LObj makeCons(LObj a, LObj d) {
  return new LObj(CONS, new Cons(a, d));
}

class Subr {
  LObj call(LObj args) { return args; }
}

class Expr {
  LObj args;
  LObj body;
  LObj env;
  Expr(LObj a, LObj b, LObj e) {
    args = a;
    body = b;
    env = e;
  }
}

LObj kNil = new LObj(NIL, "nil");

HashMap<String, LObj> symTable = new HashMap<String, LObj>();
LObj makeSym(String str) {
  if (!symTable.containsKey(str)) {
    symTable.put(str, new LObj(SYM, str));
  }
  return symTable.get(str);
}
LObj symT = makeSym("t");
LObj symQuote = makeSym("quote");

LObj safeCar(LObj obj) {
  if (obj.tag == CONS) {
    return obj.cons().car;
  }
  return kNil;
}

LObj safeCdr(LObj obj) {
  if (obj.tag == CONS) {
    return obj.cons().cdr;
  }
  return kNil;
}

LObj nreverse(LObj lst) {
  LObj ret = kNil;
  while (lst.tag == CONS) {
    LObj tmp = lst.cons().cdr;
    lst.cons().cdr = ret;
    ret = lst;
    lst = tmp;
  }
  return ret;
}

boolean isSpace(char c) {
  return c == '\t' || c == '\r' || c == '\n' || c == ' ';
}

boolean isDelimiter(char c) {
  return c == kLPar || c == kRPar || c == kQuote || isSpace(c);
}

String skipSpaces(String str) {
  int i;
  for (i = 0; i < str.length(); i++) {
    if (!isSpace(str.charAt(i))) {
      break;
    }
  }
  return str.substring(i);
}

LObj makeNumOrSym(String str) {
  try {
    return new LObj(NUM, Integer.parseInt(str));
  } catch (NumberFormatException e) {
    return makeSym(str);
  }
}

class ParseState {
  LObj obj;
  String next;
  ParseState(LObj o, String s) {
    obj = o;
    next = s;
  }
}

ParseState parseError(String str) {
  return new ParseState(new LObj(ERROR, str), "");
}

ParseState readAtom(String str) {
  String next = "";
  for (int i = 0; i < str.length(); i++) {
    if (isDelimiter(str.charAt(i))) {
      next = str.substring(i);
      str = str.substring(0, i);
      break;
    }
  }
  return new ParseState(makeNumOrSym(str), next);
}

ParseState read(String str) {
  str = skipSpaces(str);
  if (str.length() == 0) {
    return parseError("empty input");
  } else if (str.charAt(0) == kRPar) {
    return parseError("invalid syntax: " + str);
  } else if (str.charAt(0) == kLPar) {
    return readList(str.substring(1));
  } else if (str.charAt(0) == kQuote) {
    ParseState tmp = read(str.substring(1));
    return new ParseState(makeCons(symQuote, makeCons(tmp.obj, kNil)),
                          tmp.next);
  }
  return readAtom(str);
}

ParseState readList(String str) {
  LObj ret = kNil;
  while (true) {
    str = skipSpaces(str);
    if (str.length() == 0) {
      return parseError("unfinished parenthesis");
    } else if (str.charAt(0) == kRPar) {
      break;
    }
    ParseState tmp = read(str);
    if (tmp.obj.tag == ERROR) {
      return tmp;
    }
    ret = makeCons(tmp.obj, ret);
    str = tmp.next;
  }
  return new ParseState(nreverse(ret), str.substring(1));
}

LObj findVar(LObj sym, LObj env) {
  while (env.tag == CONS) {
    LObj alist = env.cons().car;
    while (alist.tag == CONS) {
      if (alist.cons().car.cons().car == sym) {
        return alist.cons().car;
      }
      alist = alist.cons().cdr;
    }
    env = env.cons().cdr;
  }
  return kNil;
}

LObj gEnv = makeCons(kNil, kNil);

void addToEnv(LObj sym, LObj val, LObj env) {
  env.cons().car = makeCons(makeCons(sym, val), env.cons().car);
}

LObj eval(LObj obj, LObj env) {
  if (obj.tag == NIL || obj.tag == NUM || obj.tag == ERROR) {
    return obj;
  } else if (obj.tag == SYM) {
    LObj bind = findVar(obj, env);
    if (bind == kNil) {
      return new LObj(ERROR, obj.str() + " has no value");
    }
    return bind.cons().cdr;
  }
  return new LObj(ERROR, "noimpl");
}

void initialize() {
  symTable.put("nil", kNil);
  addToEnv(symT, symT, gEnv);
}

void setup(){
  initialize();
  BufferedReader reader = createReader("input");
  String line;
  try {
    while ((line = reader.readLine()) != null) {
      println(eval(read(line).obj, gEnv));
    }
  } catch(IOException e) { exit(); }
  exit();
}
