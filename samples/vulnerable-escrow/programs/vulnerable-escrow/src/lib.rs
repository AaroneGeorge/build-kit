use anchor_lang::prelude::*;
use anchor_lang::system_program;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS"); // placeholder id (sample fixture only)

#[program]
pub mod vulnerable_escrow {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, min_bid: u64) -> Result<()> {
        let auction = &mut ctx.accounts.auction;
        auction.authority = ctx.accounts.authority.key();
        auction.highest_bidder = Pubkey::default();
        auction.highest_bid = 0;
        auction.min_bid = min_bid;
        auction.total_deposited = 0;
        auction.settled = false;
        Ok(())
    }

    pub fn place_bid(ctx: Context<PlaceBid>, amount: u64) -> Result<()> {
        let auction = &mut ctx.accounts.auction;
        require!(amount > auction.highest_bid, EscrowError::BidTooLow);

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: ctx.accounts.bidder.to_account_info(),
                    to: ctx.accounts.vault.to_account_info(),
                },
            ),
            amount,
        )?;

        auction.total_deposited += amount;
        auction.highest_bid = amount;
        auction.highest_bidder = ctx.accounts.bidder.key();
        Ok(())
    }

    pub fn settle(ctx: Context<Settle>, amount: u64) -> Result<()> {
        let auction = &mut ctx.accounts.auction;
        auction.total_deposited = auction.total_deposited - amount;

        **ctx.accounts.vault.to_account_info().try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.recipient.to_account_info().try_borrow_mut_lamports()? += amount;

        auction.settled = true;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = authority, space = 8 + Auction::LEN)]
    pub auction: Account<'info, Auction>,
    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct PlaceBid<'info> {
    #[account(mut)]
    pub auction: Account<'info, Auction>,
    #[account(mut)]
    pub bidder: Signer<'info>,
    /// CHECK: lamport vault for the auction
    #[account(mut)]
    pub vault: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Settle<'info> {
    #[account(mut)]
    pub auction: Account<'info, Auction>,
    /// CHECK: payout recipient
    #[account(mut)]
    pub recipient: UncheckedAccount<'info>,
    /// CHECK: lamport vault for the auction
    #[account(mut)]
    pub vault: UncheckedAccount<'info>,
    /// CHECK: auction authority
    pub authority: UncheckedAccount<'info>,
}

#[account]
pub struct Auction {
    pub authority: Pubkey,
    pub highest_bidder: Pubkey,
    pub highest_bid: u64,
    pub min_bid: u64,
    pub total_deposited: u64,
    pub settled: bool,
}

impl Auction {
    pub const LEN: usize = 32 + 32 + 8 + 8 + 8 + 1;
}

#[error_code]
pub enum EscrowError {
    #[msg("Bid must exceed current highest bid")]
    BidTooLow,
}
