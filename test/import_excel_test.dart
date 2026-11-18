import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nacrea/services/import_excel.dart';

void main() {
  test('le modèle généré se relit (colonne Photo comprise)', () {
    final lignes = lireFichier(modeleExcel(), 'modele.xlsx');
    expect(lignes.length, 2);
    expect(lignes.first.nom, 'Lait corporel karité');
    expect(lignes.first.prixVente, 4000);
    expect(lignes.first.photo, isNull);
    expect(lignes.every((l) => l.valide), isTrue);
  });

  test('colonne Photo : lien gardé, texte ignoré, « Photo du produit » pas pris pour le nom', () {
    final octets = File('test/fixtures/import_photos.xlsx').readAsBytesSync();
    final lignes = lireFichier(octets, 'import_photos.xlsx');
    expect(lignes.length, 3);
    expect(lignes[0].nom, 'Crème test');
    expect(lignes[0].variante, '50 g');
    expect(lignes[0].prixGros, 1500);
    expect(lignes[0].photo, 'https://example.com/a.jpg');
    expect(lignes[1].photo, isNull);
    expect(lignes[1].valide, isTrue);
    expect(lignes[2].photo, isNull);
  });

  test('fichier CSV sans colonne Photo : inchangé', () {
    const csv = 'Nom du produit;Prix de vente\nGel;1200\n';
    final lignes = lireFichier(Uint8List.fromList(csv.codeUnits), 'p.csv');
    expect(lignes.single.nom, 'Gel');
    expect(lignes.single.prixVente, 1200);
    expect(lignes.single.photo, isNull);
  });
}
