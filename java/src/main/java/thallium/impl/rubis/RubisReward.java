package thallium.impl.rubis;

import thallium.impl.Reward;

import java.util.stream.Stream;

final class RubisReward extends Reward {
    private final double time;
    private final double fido;
    private final double cost;

    RubisReward(final double cost, final double fido, final double time) {
        this.cost = cost;
        this.fido = fido;
        this.time = time;
    }

    double getTime() {
        return time;
    }

    double getFido() {
        return fido;
    }

    double getCost() {
        return cost;
    }

    @Override
    public boolean isDominated(Stream<? extends Reward> others) {
        return others.filter(RubisReward.class::isInstance)
                .map(RubisReward.class::cast)
                .anyMatch(this::isDominatedBy);
    }

    private boolean isDominatedBy(RubisReward other) {
        if (cost < other.cost)
            return (fido <= other.fido) && (time <= other.time);
        if (fido < other.fido)
            return (cost <= other.cost) && (time <= other.time);
        if (time < other.time)
            return (cost <= other.cost) && (fido <= other.fido);
        return false;
    }
}
