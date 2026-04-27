# mongo-local

Environnement MongoDB local prêt à l'emploi avec Docker, interface web (`mongo-express`) et script d'import CSV.

## Prérequis

- Docker Desktop installé et démarré
- Un fichier `.csv` avec une ligne d'en-tête

## Structure

- `docker-compose.yml` : stack MongoDB + Mongo Express
- `.env` : configuration centralisée
- `scripts/import-csv.sh` : import CSV vers MongoDB

## Configuration

Le fichier `.env` contient les variables principales :

- `MONGO_ROOT_USERNAME` : utilisateur admin MongoDB
- `MONGO_ROOT_PASSWORD` : mot de passe admin MongoDB
- `MONGO_PORT` : port local MongoDB (par défaut `27017`)
- `MONGO_EXPRESS_PORT` : port local Mongo Express (par défaut `8081`)
- `MONGO_EXPRESS_BASICAUTH` : active/désactive l'auth Mongo Express
- `MONGO_DEFAULT_DB` : base par défaut pour l'import

## Démarrage

Lancer les services :

```bash
docker compose up -d
```

Vérifier l'état :

```bash
docker compose ps
```

## Interfaces d'administration

- Mongo Express : `http://localhost:8081` (ou le port défini dans `.env`)
- MongoDB Compass (desktop)
  - Host : `localhost`
  - Port : `27017`
  - Username : valeur `MONGO_ROOT_USERNAME`
  - Password : valeur `MONGO_ROOT_PASSWORD`
  - Authentication Database : `admin`

URI Compass équivalente (exemple) :

```text
mongodb://admin:admin123@localhost:27017/?authSource=admin
```

## Import CSV

Commande standard :

```bash
FILE=./data/users.csv COLLECTION=users DB=app_db ./scripts/import-csv.sh
```

Paramètres :

- `FILE` (obligatoire) : chemin du fichier CSV
- `COLLECTION` (obligatoire) : nom de la collection cible
- `DB` (optionnel) : nom de la base cible (sinon `MONGO_DEFAULT_DB`)
- `DROP_FIRST` (optionnel) : `true` pour vider la collection avant import

Exemple avec remplacement complet de la collection :

```bash
FILE=./data/users.csv COLLECTION=users DB=app_db DROP_FIRST=true ./scripts/import-csv.sh
```

## Exploration avec Jupyter

Installer les dépendances Python (dans un venv recommandé) :

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Lancer Jupyter :

```bash
jupyter lab
```

Exemple minimal de connexion MongoDB dans un notebook :

```python
from pymongo import MongoClient
import pandas as pd

uri = "mongodb://admin:admin123@localhost:27017/?authSource=admin"
client = MongoClient(uri)

db = client["app_db"]
col = db["tc"]

print("Documents:", col.count_documents({}))
```

Charger un échantillon puis tout le dataset :

```python
docs = list(col.find({}, {"_id": 0}).limit(20))
df = pd.DataFrame(docs)
display(df.head())

df_all = pd.DataFrame(list(col.find({}, {"_id": 0})))
print(df_all.shape)
print(df_all.dtypes)
```

Notes importantes :

- Le dataset Telco contient la colonne `Churn Label` (pas `Churn`).
- Après import CSV, certains champs peuvent rester en `object` (ex : `Total Charges`) et nécessiter une conversion numérique avant analyse.

## Parcours notebooks modélisation

Ordre recommandé d'exécution :

1. `notebooks/01_telco_eda.ipynb`
2. `notebooks/02_telco_model_baseline.ipynb`
3. `notebooks/03_telco_random_forest.ipynb`
4. `notebooks/04_telco_random_forest_tuning.ipynb`
5. `notebooks/05_telco_model_comparison.ipynb`

### Détail de chaque notebook

`01_telco_eda.ipynb` (exploration des données)
- **Objectif** : comprendre les données avant de modéliser.
- **Ce que tu fais** : contrôle des colonnes, types, valeurs manquantes, distributions de base, premiers graphiques churn.
- **Ce que tu obtiens** : une photo claire du dataset (qualité + structure).
- **Quand l'utiliser** : en premier, ou à chaque nouvel import CSV.

`02_telco_model_baseline.ipynb` (premier modèle simple)
- **Objectif** : créer un benchmark de départ fiable.
- **Ce que tu fais** : split train/test, preprocessing, `LogisticRegression`, métriques (accuracy, precision, recall, f1, roc_auc).
- **Ce que tu obtiens** : un score de référence pour juger les futurs modèles.
- **Quand l'utiliser** : juste après `01`, avant tout tuning.

`03_telco_random_forest.ipynb` (modèle arbre de base)
- **Objectif** : tester un modèle non linéaire souvent plus performant sur données tabulaires.
- **Ce que tu fais** : même pipeline de données, entraînement `RandomForestClassifier`, confusion matrix, lecture des hyperparamètres clés.
- **Ce que tu obtiens** : comparaison directe avec la baseline logistique.
- **Quand l'utiliser** : après `02`, pour voir le gain potentiel sans tuning.

`04_telco_random_forest_tuning.ipynb` (optimisation hyperparamètres)
- **Objectif** : améliorer le RandomForest via `GridSearchCV`.
- **Ce que tu fais** : validation croisée stratifiée, recherche sur une grille large (`n_estimators`, `max_depth`, `min_samples_split`, `min_samples_leaf`, `max_features`), comparaison RF base vs RF tuned.
- **Ce que tu obtiens** : meilleurs hyperparamètres + score amélioré (si les données le permettent).
- **Quand l'utiliser** : quand le RF de base est prometteur et que tu veux maximiser la perf.

`05_telco_model_comparison.ipynb` (choix final)
- **Objectif** : comparer les modèles sur un cadre identique et prendre une décision.
- **Ce que tu fais** : benchmark harmonisé (`LogisticRegression`, `RandomForest` base/tuned, `GradientBoosting`) sur le même split.
- **Ce que tu obtiens** : tableau de comparaison + recommandation modèle orientée business.
- **Quand l'utiliser** : en fin de cycle, pour choisir le candidat à industrialiser.

### Logique globale

- `01` = comprendre les données
- `02` = poser un baseline
- `03` = tester un modèle plus puissant
- `04` = optimiser ce modèle
- `05` = arbitrer et décider

Temps d'exécution indicatif :

- `01`, `02` et `03` : quelques secondes à ~1 minute
- `04` : plusieurs minutes (GridSearch approfondi)
- `05` : ~1 à 3 minutes selon machine

Interprétation rapide des métriques :

- `recall` (churn=1) : capacité à détecter les clients à risque
- `precision` : qualité des clients ciblés par les actions de rétention
- `roc_auc` : score global utile pour comparer les modèles

Bonne pratique :

- Toujours comparer les modèles sur le même split train/test
- Faire le tuning uniquement sur le train
- Vérifier le compromis business `recall` vs `precision`, pas seulement l'accuracy

## Vérification bout en bout

1. Démarrer la stack avec `docker compose up -d`
2. Vérifier que `mongo` et `mongo-express` sont `running` via `docker compose ps`
3. Ouvrir `http://localhost:8081`
4. Lancer l'import CSV
5. Vérifier dans Mongo Express que la collection contient bien les documents
6. Vérifier dans Compass le nombre de documents et quelques champs clés
7. Vérifier dans Jupyter que `count_documents({})` et les dimensions DataFrame sont cohérentes
8. Redémarrer (`docker compose down` puis `docker compose up -d`) et confirmer la persistance

## Arrêt de la stack

```bash
docker compose down
```

## Dépannage rapide

- **Erreur de connexion MongoDB** : vérifier les identifiants `.env` et que `mongo` est `running`
- **Import échoue** : vérifier que le CSV existe, possède une extension `.csv` et une ligne d'en-tête
- **Port occupé** : changer `MONGO_PORT` ou `MONGO_EXPRESS_PORT` dans `.env`, puis relancer la stack
