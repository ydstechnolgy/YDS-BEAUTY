-- =====================================================================
-- YDS Beauty · Remettre à zéro UNE cliente (après une période d'essai)
--
-- Efface les ventes, retours, caisses, dépenses, crédits et le stock
-- d'une seule patronne. Ne touche PAS à :
--   son compte, son e-mail, ses boutiques, sa licence (et son équipe sauf choix),
--   ni aux données des autres clientes.
--
-- Mode d'emploi (Supabase > SQL Editor > New query) :
--   1. Remplacez EMAIL_DE_LA_PATRONNE par l'e-mail de la patronne.
--   2. Choisissez ce que vous gardez (true = garder, false = effacer).
--   3. Cliquez sur Run. Le tableau du bas montre ce qui a été effacé.
--
-- ATTENTION : l'effacement est définitif.
-- =====================================================================

drop table if exists pg_temp._bilan;
create temp table _bilan (element text, lignes_effacees int);

do $$
declare
  v_email          text    := 'EMAIL_DE_LA_PATRONNE';
  garder_produits  boolean := true;   -- fiches produits, catégories, fournisseurs (le stock repart de 0)
  garder_clientes  boolean := false;  -- fiches des clientes (leurs crédits sont effacés)
  garder_equipe    boolean := true;   -- employées et invitations (la patronne est toujours gardée)

  v_compte uuid;
  v_nb     int;
  n        int;
begin
  select count(distinct m.account_id), min(m.account_id::text)::uuid
    into v_nb, v_compte
  from members m
  join auth.users u on u.id = m.user_id
  where lower(u.email) = lower(trim(v_email)) and m.role = 'owner';

  if v_nb = 0 then
    raise exception 'Aucune patronne trouvée avec l''e-mail « % ». Vérifiez l''adresse.', v_email;
  elsif v_nb > 1 then
    raise exception 'Cette adresse est patronne de % entreprises : remise à zéro annulée.', v_nb;
  end if;

  -- Ventes, retours et paiements
  delete from sale_return_items where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Articles retournés', n);
  delete from sale_returns      where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Retours / échanges', n);
  delete from payments          where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Paiements des ventes', n);
  delete from sale_items        where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Lignes de vente', n);
  delete from sales             where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Ventes', n);

  -- Caisse
  delete from cash_movements    where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Entrées / sorties de caisse', n);
  delete from cash_sessions     where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Ouvertures / clôtures de caisse', n);

  -- Crédits et dépenses
  delete from customer_payments where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Remboursements de crédit', n);
  delete from expenses          where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Dépenses', n);

  -- Stock (repart de zéro)
  delete from stock_adjustments where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Ajustements de stock', n);
  delete from inventories       where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Inventaires', n);
  delete from stock_movements   where shop_id in (select id from shops where account_id = v_compte);
  get diagnostics n = row_count; insert into _bilan values ('Mouvements de stock', n);
  delete from stock_lots        where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Lots de stock', n);

  -- Clientes
  if garder_clientes then
    update customers set loyalty_points = 0 where account_id = v_compte;
  else
    delete from customers where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Clientes', n);
  end if;

  -- Produits
  if not garder_produits then
    delete from products   where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Produits', n);
    delete from categories where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Catégories', n);
    delete from suppliers  where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Fournisseurs', n);
  end if;

  -- Équipe
  if not garder_equipe then
    delete from invitations where account_id = v_compte; get diagnostics n = row_count; insert into _bilan values ('Invitations', n);
    delete from members where account_id = v_compte and role <> 'owner'; get diagnostics n = row_count; insert into _bilan values ('Employées', n);
  end if;

  insert into _bilan values ('OK : remise à zéro terminée', null);
end $$;

select * from _bilan;
