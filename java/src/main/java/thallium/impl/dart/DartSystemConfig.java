package thallium.impl.dart;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import thallium.impl.SystemConfig;

public class DartSystemConfig extends SystemConfig {
    final int altitude;
    final int formation;
    final boolean ecm;
    final int incAltProgress;
    final int decAltProgress;
    final int incAlt2Progress;
    final int decAlt2Progress;

    @JsonCreator
    DartSystemConfig(@JsonProperty("altitudeLevel") int altitude, @JsonProperty("formation") int formation, @JsonProperty("ecm") boolean ecm,
                     @JsonProperty("incAltProgress") int incAltProgress, @JsonProperty("decAltProgress") int decAltProgress,
                     @JsonProperty("incAlt2Progress") int incAlt2Progress, @JsonProperty("decAlt2Progress") int decAlt2Progress) {
        this.altitude = altitude;
        this.formation = formation;
        this.ecm = ecm;
        this.incAltProgress = 1 - incAltProgress;
        this.decAltProgress = 1 - decAltProgress;
        this.incAlt2Progress = incAlt2Progress;
        this.decAlt2Progress = decAlt2Progress;
    }


    @Override
    public int compareTo(SystemConfig o) {
        DartSystemConfig other = (DartSystemConfig) o;
        int a = altitude - other.altitude;
        if (a != 0) return a;
        int b = formation - other.formation;
        if (b != 0) return b;
        int c = (ecm == other.ecm) ? 0 : ecm ? 1 : -1;
        if (c != 0) return c;
        int d = incAltProgress - other.incAltProgress;
        if (d != 0) return d;
        int e = decAltProgress - other.decAltProgress;
        if (e != 0) return e;
        int f = incAlt2Progress - other.incAlt2Progress;
        if (f != 0) return f;
        return decAlt2Progress - other.decAlt2Progress;
    }

    @Override
    public String[] getStringValues() {
        return new String[]{
                Integer.toString(altitude),
                Integer.toString(formation),
                ecm ? "1" : "0",
                Integer.toString(incAltProgress),
                Integer.toString(decAltProgress),
                Integer.toString(incAlt2Progress),
                Integer.toString(decAlt2Progress)
        };
    }

    @Override
    public String toString() {
        return "Dart[" + String.join(",", getStringValues()) + "]";
    }
}
