package com.aptraining.catalogs;

import com.aptraining.entity.abstracts.CatalogEntity;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;


@Entity
@Table(name = "movement_patterns")
@Getter
@Setter
@AllArgsConstructor
public class MovementPattern extends CatalogEntity {
}
