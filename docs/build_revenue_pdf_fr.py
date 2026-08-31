#!/usr/bin/env python3
"""Version francaise du PDF Pick1 - reprise des revenus et projections.

Tous les chiffres sont verifies dans App Store Connect et dans la table
`subscriptions` alimentee par les App Store Server Notifications V2 d'Apple.
Rien n'est estime, sauf lorsqu'une ligne est explicitement presentee comme
une hypothese.

Conventions francaises : separateur de milliers = espace insecable,
separateur decimal = virgule, symbole monetaire apres le nombre.
"""

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, Frame, PageBreak, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)

OUT = "/Users/ethan/betting-app/docs/Pick1_Reprise_Revenus_Projections_FR.pdf"

NB = " "  # espace insecable

# ── Palette ───────────────────────────────────────────────────────────────
INK      = colors.HexColor("#14161A")
INK_2    = colors.HexColor("#4A4F57")
INK_3    = colors.HexColor("#8A8F98")
LIME     = colors.HexColor("#C3EF1F")
LIME_DK  = colors.HexColor("#5C7300")
RULE     = colors.HexColor("#DDDCD4")
RULE_LT  = colors.HexColor("#EEEDE6")
PANEL    = colors.HexColor("#F7F7F2")

PAGE_W, PAGE_H = A4
MARGIN = 18 * mm

ss = getSampleStyleSheet()


def style(name, **kw):
    base = dict(name=name, fontName="Helvetica", fontSize=9.5, leading=14,
                textColor=INK_2, alignment=TA_LEFT, spaceAfter=0)
    base.update(kw)
    return ParagraphStyle(**base)


S = {
    "title":    style("title", fontName="Helvetica-Bold", fontSize=26, leading=29,
                      textColor=INK, spaceAfter=4),
    "subtitle": style("subtitle", fontSize=11.5, leading=16, textColor=INK_2),
    "eyebrow":  style("eyebrow", fontName="Helvetica-Bold", fontSize=7.5, leading=11,
                      textColor=INK_3),
    "h2":       style("h2", fontName="Helvetica-Bold", fontSize=14.5, leading=18.5,
                      textColor=INK, spaceAfter=3),
    "body":     style("body"),
    "bodytight": style("bodytight", leading=12.5),
    "small":    style("small", fontSize=8.5, leading=12, textColor=INK_3),
    "cell":     style("cell", fontSize=8.6, leading=11.8),
    "cellb":    style("cellb", fontName="Helvetica-Bold", fontSize=8.6, leading=11.8,
                      textColor=INK),
    "cellhead": style("cellhead", fontName="Helvetica-Bold", fontSize=7.5, leading=10,
                      textColor=INK_3),
    "kpiv":     style("kpiv", fontName="Helvetica-Bold", fontSize=18, leading=20,
                      textColor=INK),
    "kpivl":    style("kpivl", fontName="Helvetica-Bold", fontSize=18, leading=20,
                      textColor=LIME_DK),
    "kpik":     style("kpik", fontName="Helvetica-Bold", fontSize=7, leading=10,
                      textColor=INK_3),
    "kpin":     style("kpin", fontSize=8, leading=11, textColor=INK_2),
}


def P(txt, s="body"):
    return Paragraph(txt, S[s])


def rule(color=RULE, thickness=0.6, space_before=0, space_after=0):
    t = Table([[""]], colWidths=[PAGE_W - 2 * MARGIN], rowHeights=[thickness])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), color),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
    ]))
    return [Spacer(1, space_before), t, Spacer(1, space_after)]


def section(eyebrow, heading):
    out = rule(RULE, 0.6, 0, 5)
    out.append(P(eyebrow.upper(), "eyebrow"))
    out.append(Spacer(1, 2))
    out.append(P(heading, "h2"))
    out.append(Spacer(1, 6))
    return out


def kpi_row(items):
    cells = []
    for v, k, n, hi in items:
        inner = [[P(v, "kpivl" if hi else "kpiv")],
                 [P(k.upper(), "kpik")],
                 [P(n, "kpin")]]
        t = Table(inner, colWidths=[(PAGE_W - 2 * MARGIN) / len(items) - 6])
        t.setStyle(TableStyle([
            ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ("TOPPADDING", (0, 0), (-1, -1), 1),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]))
        cells.append(t)
    outer = Table([cells], colWidths=[(PAGE_W - 2 * MARGIN) / len(items)] * len(items))
    outer.setStyle(TableStyle([
        ("LEFTPADDING", (0, 0), (0, -1), 0),
        ("RIGHTPADDING", (-1, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEABOVE", (0, 0), (-1, 0), 2, LIME),
    ]))
    return outer


def data_table(header, rows, widths, aligns=None, highlight_col=None):
    body = [[P(h, "cellhead") for h in header]]
    for r in rows:
        body.append([c if isinstance(c, Paragraph) else P(str(c), "cell") for c in r])
    t = Table(body, colWidths=widths, repeatRows=1)
    st = [
        ("LINEBELOW", (0, 0), (-1, 0), 0.7, RULE),
        ("LINEBELOW", (0, 1), (-1, -2), 0.4, RULE_LT),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (0, -1), 0),
        ("RIGHTPADDING", (-1, 0), (-1, -1), 0),
    ]
    if aligns:
        for i, a in enumerate(aligns):
            st.append(("ALIGN", (i, 0), (i, -1), a))
    if highlight_col is not None:
        st.append(("TEXTCOLOR", (highlight_col, 1), (highlight_col, -1), LIME_DK))
        st.append(("FONTNAME", (highlight_col, 1), (highlight_col, -1), "Helvetica-Bold"))
    t.setStyle(TableStyle(st))
    return t


def callout(paras):
    inner = [[P(p, "bodytight")] for p in paras]
    t = Table(inner, colWidths=[PAGE_W - 2 * MARGIN - 14])
    t.setStyle(TableStyle([
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    outer = Table([[t]], colWidths=[PAGE_W - 2 * MARGIN])
    outer.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PANEL),
        ("LINEBEFORE", (0, 0), (0, -1), 2.5, LIME),
        ("LEFTPADDING", (0, 0), (-1, -1), 11),
        ("RIGHTPADDING", (0, 0), (-1, -1), 11),
        ("TOPPADDING", (0, 0), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
    ]))
    return outer


def decorate(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica-Bold", 8)
    canvas.setFillColor(INK_3)
    canvas.drawString(MARGIN, PAGE_H - 12 * mm, "PICK1")
    canvas.setFillColor(LIME_DK)
    canvas.drawString(MARGIN + 22, PAGE_H - 12 * mm, "REPRISE DES REVENUS ET PROJECTIONS")
    canvas.setFillColor(INK_3)
    canvas.drawRightString(PAGE_W - MARGIN, PAGE_H - 12 * mm, "28 JUILLET 2026")
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN, PAGE_H - 14.5 * mm, PAGE_W - MARGIN, PAGE_H - 14.5 * mm)
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(INK_3)
    canvas.drawString(MARGIN, 11 * mm,
                      "Chiffres verifies dans App Store Connect et les App Store Server "
                      "Notifications d'Apple.")
    canvas.drawRightString(PAGE_W - MARGIN, 11 * mm, f"{doc.page}")
    canvas.restoreState()


doc = BaseDocTemplate(OUT, pagesize=A4,
                      leftMargin=MARGIN, rightMargin=MARGIN,
                      topMargin=20 * mm, bottomMargin=16 * mm,
                      title="Pick1 - Reprise des revenus et projections",
                      author="L70 Labs")
frame = Frame(MARGIN, 16 * mm, PAGE_W - 2 * MARGIN, PAGE_H - 36 * mm, id="body",
              leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=decorate)])

W = PAGE_W - 2 * MARGIN
story = []

# ══════════════════════════════════════════════════════════════ PAGE 1 ════
story.append(Spacer(1, 4))
story.append(P("Reconquérir le chiffre d’affaires", "title"))
story.append(Spacer(1, 4))
story.append(P(
    "Ce que vaut la base d’abonnés actuelle si rien ne change, pourquoi elle s’érode, "
    "et ce que chaque levier de reconquête devrait rapporter.", "subtitle"))
story.append(Spacer(1, 14))

story.append(kpi_row([
    ("1" + NB + "071" + NB + "$", "Revenus depuis le lancement",
     "Dont 1 043 $ sur seulement 15 jours.", False),
    ("86", "Abonnements actifs",
     "Dont 53 seulement seront à nouveau facturés.", False),
    ("56" + NB + "$", "Engagés par jour",
     "Abonnés payants en renouvellement automatique.", True),
    ("~3" + NB + "$", "Par jour à 90 jours",
     "Même base, sans aucune intervention.", False),
]))

story += section("Le constat", "La base actuelle vaut environ 1 000 $ sur 90 jours")
story.append(P(
    "Pick1 a généré <b>1"+NB+"071"+NB+"$ depuis son lancement</b>, dont 1"+NB+"043"+NB+"$ sur une "
    "seule fenêtre de 15 jours en juillet, lorsque la vague d’inscriptions de la Coupe du monde a "
    "franchi l’essai gratuit de 3 jours. Le pic a été atteint le 21 juillet à 147"+NB+"$ — soit deux "
    "jours <i>après</i> la finale — et le chiffre d’affaires recule depuis, à mesure que cette "
    "cohorte s’épuise.", "body"))
story.append(Spacer(1, 7))
story.append(P(
    "Projetée dans le temps, l’ensemble des abonnés actuels générera environ "
    "<b>1"+NB+"014"+NB+"$ sur les 90 prochains jours</b>. Autrement dit, toute la base active vaut "
    "désormais à peu près autant que ce que l’application a gagné durant toute son existence. Ce "
    "n’est pas un problème d’acquisition : environ 11 nouveaux abonnements arrivent encore chaque "
    "jour. C’est un problème de rétention.", "body"))
story.append(Spacer(1, 10))

story.append(callout([
    "<b>Le seul indicateur déjà excellent.</b> Les référentiels d’Apple situent le revenu par "
    "abonné payant de Pick1 à <b>28,00"+NB+"$</b>, au-dessus du 75<super>e</super> centile des applications Sport "
    "par abonnement (19,05"+NB+"$). Le prix est l’atout le plus solide de l’activité et ne doit pas "
    "être baissé. Le problème est que trop peu de personnes commencent à payer, et que celles qui "
    "paient partent après un seul cycle.",
]))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 2 ════
story += section("Ce qu’il reste", "La base active, abonné par abonné")
story.append(P(
    "86 abonnements sont actifs aujourd’hui. Seuls 53 ont le renouvellement automatique activé : "
    "les 33 autres ont déjà résilié et laissent simplement filer leur période en cours. Cette "
    "distinction résume toute la projection.", "body"))
story.append(Spacer(1, 10))

story.append(data_table(
    ["Groupe", "Abon.", "Net / cycle", "Net / jour", "Ce qui va se passer"],
    [
        ["Hebdo, payant, en renouvellement", "28", "333,32"+NB+"$", "47,62"+NB+"$",
         "Facturé tous les 7 jours. 27"+NB+"% survivent au prélèvement suivant."],
        ["Mensuel, payant, en renouvellement", "8", "260,92"+NB+"$", "8,58"+NB+"$",
         "Facturé tous les 30 jours. Meilleure rétention de la base."],
        ["Hebdo, en essai gratuit", "17", "234,08"+NB+"$", "—",
         "Convertit à 12,2"+NB+"%, soit environ 2 futurs payants."],
        [P("<b>Résilié, encore actif</b>", "cellb"), P("<b>33</b>", "cellb"),
         P("<b>0"+NB+"$</b>", "cellb"), P("<b>0"+NB+"$</b>", "cellb"),
         P("<b>Expirera. Aucun revenu supplémentaire sans reconquête.</b>", "cellb")],
    ],
    widths=[W * 0.28, W * 0.07, W * 0.15, W * 0.13, W * 0.37],
    aligns=["LEFT", "RIGHT", "RIGHT", "RIGHT", "LEFT"],
))
story.append(Spacer(1, 6))
story.append(P(
    "Le revenu engagé par les abonnés payants en renouvellement est de <b>56,20"+NB+"$ par jour</b>. "
    "Les 17 essais ajoutent environ 4"+NB+"$ par jour une fois le taux de conversion appliqué. "
    "Devises converties à des taux approximatifs, montants nets de la commission Apple de "
    "15"+NB+"%.", "small"))
story.append(Spacer(1, 14))

story += section("La projection", "Même base, sans intervention")
story.append(P(
    "En appliquant les taux de rétention observés — 27"+NB+"% des abonnés hebdomadaires survivent au "
    "prélèvement suivant, et 12,2"+NB+"% des essais se convertissent — la base actuelle s’érode "
    "ainsi.", "body"))
story.append(Spacer(1, 10))

story.append(data_table(
    ["Période", "Hebdo", "Mensuel", "Essais", "Total", "Moyenne / jour"],
    [
        ["Jours 1 à 30", "454"+NB+"$", "261"+NB+"$", "39"+NB+"$",
         P("<b>754"+NB+"$</b>", "cellb"), "25"+NB+"$"],
        ["Jours 31 à 60", "8"+NB+"$", "157"+NB+"$", "—",
         P("<b>165"+NB+"$</b>", "cellb"), "6"+NB+"$"],
        ["Jours 61 à 90", "—", "94"+NB+"$", "—",
         P("<b>95"+NB+"$</b>", "cellb"), "3"+NB+"$"],
        [P("<b>Total 90 jours</b>", "cellb"), P("<b>462"+NB+"$</b>", "cellb"),
         P("<b>512"+NB+"$</b>", "cellb"), P("<b>39"+NB+"$</b>", "cellb"),
         P("<b>1"+NB+"014"+NB+"$</b>", "cellb"), P("<b>11"+NB+"$</b>", "cellb")],
    ],
    widths=[W * 0.20, W * 0.14, W * 0.14, W * 0.12, W * 0.18, W * 0.22],
    aligns=["LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT", "RIGHT"],
))
story.append(Spacer(1, 8))
story.append(P(
    "Le chiffre d’affaires part d’environ 56"+NB+"$ par jour pour finir près de 3"+NB+"$. À noter : "
    "les abonnés mensuels — ils ne sont que 8 — rapportent davantage sur 90 jours que les 28 "
    "abonnés hebdomadaires réunis. C’est le fait le plus important de cette page.", "body"))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 3 ════
story += section("Pourquoi la base s’érode", "Trois fuites, toutes mesurables")

story.append(data_table(
    ["Fuite", "Pick1", "Référence", "Ce que cela coûte"],
    [
        ["Essai converti en abonnement payant", "12,2"+NB+"%", "30 à 40"+NB+"% habituels",
         "484 abonnements sur 551 se sont arrêtés à exactement 3,0 jours — au mur de l’essai, sans jamais atteindre un premier paiement."],
        ["Abonné hebdo survivant au 2<super>e</super> prélèvement", "27"+NB+"%", "50 à 60"+NB+"% habituels",
         "67 premiers paiements sont devenus 18 deuxièmes paiements, puis 2 troisièmes."],
        ["Abonnements perdus sur échec de carte", "17,6"+NB+"%", "5 à 8"+NB+"%",
         "102 abonnements sur 573 n’ont jamais choisi de partir. Le paiement a été refusé et rien ne les en a informés."],
        ["Téléchargement devenu abonné payant", "1,48"+NB+"%", "2,68"+NB+"% (médiane)",
         "Rejoindre la médiane du secteur multiplie le chiffre d’affaires par 1,8 à trafic identique."],
        ["Retour de l’utilisateur au jour 1", "20,7"+NB+"%", "26,0"+NB+"% (médiane)",
         "Un utilisateur qui ne revient jamais une deuxième fois ne se convertit jamais."],
    ],
    widths=[W * 0.30, W * 0.11, W * 0.18, W * 0.41],
    aligns=["LEFT", "RIGHT", "LEFT", "LEFT"],
    highlight_col=1,
))
story.append(Spacer(1, 8))
story.append(P(
    "La formule hebdomadaire aggrave tout cela. À 14,99"+NB+"$ par semaine, elle impose quatre "
    "décisions de résiliation par mois, et environ trois quarts des abonnés sont perdus à chacune. "
    "Le mensuel est pourtant déjà l’option par défaut sur la page d’abonnement et revient "
    "<b>38"+NB+"% moins cher par semaine</b> (9,23"+NB+"$ contre 14,99"+NB+"$) — et malgré cela "
    "79"+NB+"% des abonnés choisissent l’hebdomadaire, parce que 14,99"+NB+"$ est un chiffre plus "
    "petit que 39,99"+NB+"$.", "body"))
story.append(Spacer(1, 14))

story += section("Déjà corrigé", "Mis en production le 28 juillet")

story.append(data_table(
    ["Changement", "Statut", "Ce que cela corrige"],
    [
        ["Délai de grâce de facturation Apple (16 jours)", "Actif",
         "Jamais activé jusqu’ici. Les échecs de carte se transformaient directement en résiliations — 17,6"+NB+"% de la base. Apple relance désormais pendant 16 jours pendant que l’abonné conserve son accès."],
        ["Notification d’échec de paiement", "Actif",
         "Informe l’abonné du refus de sa carte et le renvoie vers l’écran qui permet de la corriger. Rien ne le faisait auparavant."],
        ["Notification de rétention avant résiliation", "Actif",
         "Touche les abonnés ayant désactivé le renouvellement, 16 à 48 heures avant l’expiration. Premier contact jamais établi avec ce segment."],
        ["Notification de retour au jour 1", "Actif",
         "S’attaque directement au taux de rétention de 20,7"+NB+"% au premier jour."],
        ["Notification de fin d’essai", "Actif",
         "Deux versions, selon que l’abonné a déjà résilié ou non."],
        ["Relance par e-mail, 7 langues", "Prêt, en attente",
         "Touche les 30"+NB+"% d’abonnés perdus injoignables par notification. En attente d’une seule clé d’API manquante."],
    ],
    widths=[W * 0.30, W * 0.12, W * 0.58],
    aligns=["LEFT", "LEFT", "LEFT"],
))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 4 ════
story += section("D’où viendra la reconquête", "Deux audiences, chiffrées")
story.append(P(
    "Au-delà des 86 abonnements actifs, il existe deux populations bien plus larges, qui appellent "
    "des traitements totalement différents.", "body"))
story.append(Spacer(1, 10))

story.append(data_table(
    ["Audience", "Pers.", "Joignables", "L’action", "Reconquête estimée"],
    [
        ["Ont essayé, n’ont jamais payé", "338", "158",
         "Un mois complet à prix réduit — assez long pour voir la tendance que 3 jours n’ont jamais montrée.",
         "3 à 8"+NB+"%"],
        ["Perdus sur échec de carte", "96", "65",
         "Déjà traité par le délai de grâce et la notification d’échec de paiement.",
         "40 à 60"+NB+"%"],
        ["Ont payé, puis sont partis", "16", "9",
         "Assez peu nombreux pour une approche individuelle. Disposition à payer déjà prouvée.",
         "15 à 25"+NB+"%"],
        ["Ont l’app, n’ont jamais payé", "2"+NB+"012", "227 actifs / 7"+NB+"j",
         "Refonte de la page d’abonnement et offre de premier achat. L’opportunité qui se cumule.",
         "×1,8"],
    ],
    widths=[W * 0.21, W * 0.08, W * 0.13, W * 0.42, W * 0.16],
    aligns=["LEFT", "RIGHT", "RIGHT", "LEFT", "RIGHT"],
    highlight_col=1,
))
story.append(Spacer(1, 8))
story.append(P(
    "Précision sur le mécanisme : les offres de reconquête (Win-Back Offers) d’Apple ne sont pas "
    "utilisables ici. Apple exige que le client ait déjà payé au moins un mois pour être éligible, "
    "or la durée payée typique chez Pick1 est d’une seule semaine — quasiment aucun des 452 "
    "abonnés perdus n’y a donc droit. Les codes promotionnels ne comportent pas cette restriction "
    "et fonctionnent aussi sur l’audience n’ayant jamais payé.", "small"))
story.append(Spacer(1, 14))

story += section("Scénarios", "À quoi ressemblent les 90 prochains jours")

story.append(data_table(
    ["", "Sans rien faire", "En exécutant le plan"],
    [
        ["Revenus de la base active actuelle", "1"+NB+"014"+NB+"$", "1"+NB+"250 à 1"+NB+"500"+NB+"$"],
        ["Revenus ponctuels de reconquête", "0"+NB+"$", "400 à 900"+NB+"$"],
        ["Rythme au 90<super>e</super> jour", "20 à 25"+NB+"$ / jour", "50 à 80"+NB+"$ / jour"],
        ["Essai converti en payant", "12,2"+NB+"%", "18 à 22"+NB+"%"],
        ["Hebdo survivant au 2<super>e</super> prélèvement", "27"+NB+"%", "38 à 45"+NB+"%"],
        ["Perdus sur échec de carte", "17,6"+NB+"%", "moins de 8"+NB+"%"],
        [P("<b>Revenus sur 90 jours</b>", "cellb"), P("<b>~1"+NB+"700"+NB+"$</b>", "cellb"),
         P("<b>~3"+NB+"400 à 4"+NB+"800"+NB+"$</b>", "cellb")],
    ],
    widths=[W * 0.44, W * 0.28, W * 0.28],
    aligns=["LEFT", "RIGHT", "RIGHT"],
    highlight_col=2,
))
story.append(Spacer(1, 8))
story.append(P(
    "Le scénario « sans rien faire » intègre déjà la dizaine de nouveaux abonnements qui arrivent "
    "chaque jour aux taux de conversion actuels : ce n’est pas une base à zéro. L’écart entre les "
    "deux colonnes tient entièrement à la rétention et à la conversion, sans aucune dépense "
    "publicitaire supplémentaire de part et d’autre.", "small"))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 5 ════
story += section("Ordre des travaux", "Séquencé pour ne rien bloquer derrière un test lent")

story.append(data_table(
    ["Quand", "Quoi", "Pourquoi cet ordre"],
    [
        ["Jours 1 à 7",
         "Débloquer l’e-mail. Publier un code promotionnel « mois à prix réduit » et l’envoyer aux 452 abonnés perdus via le système de notifications déjà en place. Approcher individuellement les 16 anciens payants.",
         "Rien de tout cela ne dépend d’un nouveau trafic. C’est le seul revenu immédiatement disponible."],
        ["Jours 8 à 21",
         "Refondre la page d’abonnement : mettre en avant le registre public des résultats et présenter l’hebdomadaire face au mensuel pour rendre la comparaison de valeur évidente. Activer les notifications de résultats pour les utilisateurs gratuits.",
         "Concerne tous les futurs abonnés. Un abonné mensuel vaut trois à quatre fois un abonné hebdomadaire."],
        ["Semaines 4 à 9",
         "Tester un essai gratuit de 7 jours face à l’essai actuel de 3 jours.",
         "À environ 10 démarrages d’essai par jour, il faut 4 à 6 semaines pour une lecture honnête : le test doit donc démarrer tôt. Résultats à l’ouverture de la saison NFL."],
    ],
    widths=[W * 0.13, W * 0.52, W * 0.35],
    aligns=["LEFT", "LEFT", "LEFT"],
))
story.append(Spacer(1, 14))

story += section("Ce dont nous avons besoin", "Trois décisions et une clé")

story.append(data_table(
    ["Élément", "Responsable", "Détail"],
    [
        ["Clé d’API Resend", "Client",
         "Une seule variable d’environnement manquante. Elle débloque l’e-mail vers les 220 abonnés perdus injoignables par notification — et active également l’e-mail de bienvenue ainsi que les alertes de nouvel abonné, qui n’ont jamais fonctionné."],
        ["Niveau de remise de l’offre de retour", "Client",
         "Une campagne de codes promotionnels existe déjà dans App Store Connect à −50"+NB+"% sur le premier mois, créée mais jamais envoyée à personne. Confirmer les 50"+NB+"% ou fixer un autre niveau."],
        ["Type de code", "Client",
         "Un code unique réutilisable est bien plus simple à diffuser par notification et par e-mail. Des codes individuels à usage unique offrent plus de contrôle mais exigent une attribution par utilisateur."],
        ["Refonte de la page d’abonnement", "Les deux",
         "Validation pour modifier la mise en page et la présentation des formules. Nécessite un cycle de validation App Store."],
    ],
    widths=[W * 0.26, W * 0.12, W * 0.62],
    aligns=["LEFT", "LEFT", "LEFT"],
))
story.append(Spacer(1, 14))

story.append(callout([
    "<b>Ce que ce plan ne fait pas.</b> Tout ce qui précède augmente le revenu par utilisateur. "
    "Rien n’augmente le nombre d’utilisateurs. Au rythme actuel d’environ 67 inscriptions par jour, "
    "exécuter l’ensemble amène l’activité autour de 50 à 80"+NB+"$ par jour — une vraie reprise pour "
    "une base qui, sinon, s’érode vers zéro, mais un plafond plutôt qu’une courbe de croissance.",
    "<b>La croissance suppose de relancer la publicité.</b> Et l’argument se renforce après ces "
    "travaux, il ne s’affaiblit pas : la conversion organique inscription → abonnement tourne "
    "désormais autour de 27"+NB+"%, contre 9,9"+NB+"% pendant la vague de la Coupe du monde. Un "
    "dollar publicitaire y achètera donc environ trois fois plus qu’en juillet. On répare "
    "l’entonnoir d’abord, on le remplit ensuite.",
]))

doc.build(story)
print(f"Écrit : {OUT}")
