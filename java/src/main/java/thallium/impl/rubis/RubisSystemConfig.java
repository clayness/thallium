package thallium.impl.rubis;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import thallium.impl.SystemConfig;

@JsonIgnoreProperties("coldCache")
public class RubisSystemConfig extends SystemConfig {
    final int progress;
    final int servers;
    final int dimmer;

    @JsonCreator
    RubisSystemConfig(@JsonProperty("d") int dimmer, @JsonProperty("addServerProgress") int progress, @JsonProperty("s") int servers) {
        this.progress = progress;
        this.servers = servers;
        this.dimmer = dimmer;
    }

    @Override
    public int compareTo(SystemConfig o) {
        RubisSystemConfig other = (RubisSystemConfig) o;
        int a = servers - other.servers;
        if (a != 0) return a;
        int b = dimmer - other.dimmer;
        if (b != 0) return b;
        return progress - other.progress;
    }

    @Override
    public String[] getStringValues() {
        return new String[]{Integer.toString(servers), Integer.toString(progress), Integer.toString(dimmer)};
    }
}
