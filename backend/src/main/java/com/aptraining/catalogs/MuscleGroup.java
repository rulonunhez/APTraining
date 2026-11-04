package com.aptraining.catalogs;

import com.aptraining.entity.abstracts.CatalogEntity;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "muscle_groups")
@Getter
@Setter
@AllArgsConstructor
public class MuscleGroup extends CatalogEntity {
}
