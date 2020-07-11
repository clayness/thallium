open util/ordering[D]   as dimmer
open util/ordering[TAP] as progress // tactic add progress
open util/ordering[S]   as servers

abstract sig TP {} // tactic progress
sig TAP extends TP {} // one sig for each tactic with latency

abstract sig T {} // tactics
abstract sig LT extends T {} // tactics with latency
one sig IncDimmer, DecDimmer, RemoveServer extends T {} // tactics with no latency
one sig AddServer extends LT {} // tactics with latency

// define configuration properties
sig S {} // the different number of active servers
sig D {} // the different dimmer levels

/* each element of C represents a configuration */
abstract sig C {
  s : S, // the number of active servers
  d : D // dimmer level
}

fact noAddServerOnMax {
  all cp : CP | cp.s = servers/last implies cp.p[AddServer] = progress/last
}

pred equals[c, c2 : C] {
  all f : C$.fields | c.(f.value) = c2.(f.value) 
}

pred equalsExcept[c, c2 : C, ef : univ] {
  all f : C$.fields | f=ef or c.(f.value) = c2.(f.value) 
}

fact uniqueInstances { all disj c, c2 : CP | !equals[c, c2] or c.p != c2.p}


/*
 * this sig is a config extended with the progress of each tactic with latency
 */
sig CP extends C {
  p: LT -> TP
} {
  ~p.p in iden // functional (i.e., p maps each tactic to at most one progress)
  //#p = #LT // every tactic in LT has a mapping in p
  p.univ = LT // every tactic in LT has a mapping in p (p.univ is domain(p) )
  p[AddServer] in TAP // restrict each tactic to its own progress class
}


pred addServerTacticProgress[c, c' : CP] {
  c.p[AddServer] != progress/last implies { // tactic is running
    c'.p[AddServer] = progress/next[c.p[AddServer]]
    c'.p[AddServer] = progress/last implies c'.s = servers/next[c.s] else c'.s = c.s
  } else {
    c'.p[AddServer] = progress/last // stay in not running state
    c'.s = c.s
  }

  // nothing else changes other than s and the progress
  equalsExcept[c, c', C$s]
  (LT - AddServer) <: c.p in c'.p
}

pred oneStepProgress[c, c' : CP] { // is c' reachable from config c in one evaluation period?
  addServerTacticProgress[c, c'] // this should be the composition of the progress predicate for all the tactics
}

sig Result {
  c, c' : CP
} {
  oneStepProgress[c, c']
}

// this reduces the number of unused configurations
fact reduceUsedConfigs {
  all cp : CP | {some r : Result | r.c = cp or r.c' = cp }
}

pred show {
}

/*
 * (numOfTacticsWithLatency + 1) for CP and C to allow the progress for all the tactics with latency + the initial state
 * These are not set in Java because they depend only on the number of tactics, so they
 * are generated here.
 */
run show for exactly /*MAX_SERVERS=*/6 S, exactly /*MAX_PROGRESS=*/2 TAP, exactly /*MAX_DIMMER=*/2 D, 2 C, 2 CP, exactly 1 Result

