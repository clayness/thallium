module deltaiot

open util/ordering[DistributionSetting] as DistributionStep
open util/ordering[PowerSetting]        as PowerStep

open util/ordering[TraceElement] as trace

sig DistributionSetting {}
sig PowerSetting {}

one sig Gateway {}

sig Mote {
  parents : some Mote + Gateway
} {
  parents = this[sender].recipient
}

fact {
  all m : Mote | #m.parents < 3 and Gateway in m.^parents
  no  m : Mote | m in m.^parents
}

sig Link {
  sender    : one Mote,
  recipient : one Mote + Gateway
} {
  recipient in sender.parents
}

sig CP {
  distribution : Link -> one DistributionSetting,
  power        : Link -> one PowerSetting
} {
  distribution.univ = Link
  power.univ        = Link
}

sig TraceElement {
  cp     : one CP,
  starts : Link -> set Tactic
}

abstract sig Tactic {}
one sig IncDistribution, DecDistribution extends Tactic {}
one sig IncPower, DecPower extends Tactic {}

pred IncDistributionReady[e : TraceElement, l : Link] {
	no (IncDistribution + DecDistribution) & e.starts[l]
  e.cp.distribution[l] != DistributionStep/last
}
pred IncDistributionStart[e,e' : TraceElement, l : Link] {
  IncDistributionReady[e,l]
  e'.starts[l] = e.starts[l] + IncDistribution
  e'.cp.distribution[l] = DistributionStep/next[e.cp.distribution[l]]
}
pred DecDistributionReady[e : TraceElement, l : Link] {
	no (IncDistribution + DecDistribution) & e.starts[l]
  e.cp.distribution[l] != DistributionStep/first
}
pred DecDistributionStart[e,e' : TraceElement, l : Link] {
  DecDistributionReady[e,l]
  e'.starts[l] = e.starts[l] + DecDistribution
  e'.cp.distribution[l] = DistributionStep/prev[e.cp.distribution[l]]
}
pred IncPowerReady[e : TraceElement, l : Link] {
	no (IncPower + DecPower) & e.starts[l]
  e.cp.power[l] != PowerStep/last
}
pred IncPowerStart[e,e' : TraceElement, l : Link] {
  IncPowerReady[e,l]
  e'.starts[l] = e.starts[l] + IncPower
  e'.cp.power[l] = PowerStep/next[e.cp.power[l]]
}
pred DecPowerReady[e : TraceElement, l : Link] {
	no (IncPower + DecPower) & e.starts[l]
  e.cp.power[l] != PowerStep/first
}
pred DecPowerStart[e,e' : TraceElement, l : Link] {
  DecPowerReady[e,l]
  e'.starts[l] = e.starts[l] + DecPower
  e'.cp.power[l] = PowerStep/prev[e.cp.power[l]]
}

fact {
  // no unattached configurations
  CP in TraceElement.cp
  // no duplicate links
  no disj l,l' : Link | l.recipient = l'.recipient and l.sender = l'.sender
  // nothing changes without a corresponding adaptation
  all l : Link, e : TraceElement - trace/last | let e' = next[e] {
    (e.cp.distribution[l] = trace/next[e].cp.distribution[l])
      or (some (IncDistribution + DecDistribution) & e'.starts[l])
    (e.cp.power[l] = trace/next[e].cp.power[l])
      or (some (IncPower + DecPower) & e'.starts[l])
  }
  // apply the tactics to the trace
  all l : Link, e : TraceElement - trace/last | let e' = next[e] {
    no e'.starts[l] => { 
      e.cp = e'.cp
    } else {
      (IncDistributionStart[e,e',l] or DecDistributionStart[e,e',l])
        or 
      (IncPowerStart[e,e',l] or DecPowerStart[e,e',l])
    }
  }
  // the first trace element is empty
  all l : Link | no (trace/first).starts[l]
}

pred show {
  some disj m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15 : Mote {
    m2.parents = m4
    m3.parents = Gateway
    m4.parents = Gateway
    m5.parents = m9
    m6.parents = m4
    m7.parents = m2 + m3
    m8.parents = Gateway
    m9.parents = Gateway
    m10.parents = m5 + m6
    m11.parents = m7
    m12.parents = m3 + m7
    m13.parents = m11
    m14.parents = m12
    m15.parents = m12
  }
}
run show for 
  exactly 17 Link, 
  exactly 14 Mote,
  exactly 3 PowerSetting, 
  exactly 3 DistributionSetting,
  exactly 2 TraceElement, 
  2 CP

/*pred DeltaIoT2 { 
  some disj     m02,m03,m04,m05,m06,m07,m08,m09,m10, 
            m11,m12,m13,m14,m15,m16,m17,m18,m19,m20,
            m21,m22,m23,m24,m25,m26,m27,m28,m29,m30,
            m31,m32,m33,m34,m35,m36,m37 : Mote {
    m02.parents = m03
    m03.parents = m04 + m06
    m04.parents = m05
    m05.parents = Gateway
    m06.parents = m05 + m12
    m07.parents = m22
    m08.parents = m21
    m09.parents = m02
    m10.parents = m11
    m11.parents = m12
    m12.parents = Gateway
    m13.parents = m14
    m14.parents = m25 + m26
    m15.parents = m10
    m16.parents = m17 + m19
    m17.parents = m18
    m18.parents = Gateway
    m19.parents = m18
    m20.parents = Gateway
    m21.parents = Gateway
    m22.parents = m21 + m23
    m23.parents = m21
    m24.parents = m21
    m25.parents = m10
    m26.parents = m15
    m27.parents = m28
    m28.parents = m20
    m29.parents = m20
    m30.parents = m31
    m31.parents = Gateway
    m32.parents = m31
    m33.parents = m29
    m34.parents = m33
    m35.parents = m27 + m30
    m36.parents = m32
    m37.parents = m32
  }
}
run DeltaIoT2 for 
  exactly 42 Link, 
  exactly 36 Mote, 
  exactly 22 PowerSetting, 
  exactly 6 DistributionSetting, 
  exactly 6 SpreadSetting,
  exactly 2 TraceElement,
  2 CP
*/
